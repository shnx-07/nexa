use serde::Serialize;
use std::{
    collections::{HashMap, HashSet},
    env,
    fs,
    path::{Path, PathBuf},
    process::{Command, Stdio},
};
use walkdir::WalkDir;



#[derive(Debug, Clone, Serialize)]
pub struct AppEntry {
    pub id: String,
    pub name: String,
    pub generic_name: Option<String>,
    pub comment: Option<String>,
    pub icon: Option<String>,
    pub exec: String,
    pub terminal: bool,
    pub category_id: String,
    pub category_name: String,
    pub keywords: Vec<String>,
}

#[derive(Debug, Clone)]
struct DiscoveredApp {
    app: AppEntry,
    desktop_file: PathBuf,
}

#[derive(Debug, Serialize)]
pub struct CategoryGroup {
    pub id: String,
    pub name: String,
    pub count: usize,
    pub apps: Vec<AppEntry>,
}

#[derive(Debug, Serialize)]
pub struct LauncherPayload {
    pub total: usize,
    pub categories: Vec<CategoryGroup>,
}

#[derive(Debug, Serialize)]
pub struct SearchPayload {
    pub query: String,
    pub count: usize,
    pub results: Vec<AppEntry>,
}

#[derive(Debug, Serialize)]
struct ActionResponse {
    success: bool,
    action: &'static str,
    id: Option<String>,
    message: String,
}

#[derive(Debug, Default)]
struct DesktopEntryData {
    values: HashMap<String, String>,
}

fn xdg_application_dirs() -> Vec<PathBuf> {
    let mut dirs = Vec::new();

    let data_home = env::var_os("XDG_DATA_HOME")
        .map(PathBuf::from)
        .or_else(|| {
            env::var_os("HOME")
                .map(PathBuf::from)
                .map(|home| home.join(".local/share"))
        });

    if let Some(path) = data_home {
        dirs.push(path.join("applications"));
    }

    let data_dirs = env::var("XDG_DATA_DIRS")
        .unwrap_or_else(|_| "/usr/local/share:/usr/share".to_string());

    for dir in data_dirs.split(':').filter(|value| !value.is_empty()) {
        dirs.push(PathBuf::from(dir).join("applications"));
    }

    dirs
}

fn desktop_id(base: &Path, path: &Path) -> Option<String> {
    let relative = path.strip_prefix(base).ok()?;

    let mut id = relative
        .to_string_lossy()
        .replace(['/', '\\'], "-");

    if !id.ends_with(".desktop") {
        return None;
    }

    while id.starts_with('-') {
        id.remove(0);
    }

    if id.is_empty() {
        None
    } else {
        Some(id)
    }
}

fn parse_desktop_entry(path: &Path) -> Option<DesktopEntryData> {
    let content = fs::read_to_string(path).ok()?;

    let mut data = DesktopEntryData::default();
    let mut in_desktop_entry = false;

    for raw_line in content.lines() {
        let line = raw_line.trim();

        if line.is_empty() || line.starts_with('#') {
            continue;
        }

        if line.starts_with('[') && line.ends_with(']') {
            if in_desktop_entry {
                break;
            }

            in_desktop_entry = line == "[Desktop Entry]";
            continue;
        }

        if !in_desktop_entry {
            continue;
        }

        let Some((key, value)) = line.split_once('=') else {
            continue;
        };

        data.values
            .entry(key.trim().to_string())
            .or_insert_with(|| value.trim().to_string());
    }

    if data.values.is_empty() {
        None
    } else {
        Some(data)
    }
}

fn value<'a>(
    data: &'a DesktopEntryData,
    key: &str,
) -> Option<&'a str> {
    data.values
        .get(key)
        .map(String::as_str)
}

fn desktop_bool(
    data: &DesktopEntryData,
    key: &str,
) -> bool {
    value(data, key)
        .map(|value| {
            matches!(
                value
                    .trim()
                    .to_ascii_lowercase()
                    .as_str(),
                "true" | "1" | "yes"
            )
        })
        .unwrap_or(false)
}

fn locale_candidates() -> Vec<String> {
    let raw = env::var("LC_MESSAGES")
        .ok()
        .filter(|value| !value.is_empty())
        .or_else(|| env::var("LANG").ok())
        .unwrap_or_default();

    if raw.is_empty()
        || raw == "C"
        || raw == "POSIX"
    {
        return Vec::new();
    }

    let without_encoding =
        raw.split('.')
            .next()
            .unwrap_or(&raw);

    let mut candidates = Vec::new();

    let (base, modifier) =
        match without_encoding.split_once('@') {
            Some((base, modifier)) => {
                (base, Some(modifier))
            }

            None => {
                (without_encoding, None)
            }
        };

    let (language, territory) =
        match base.split_once('_') {
            Some((language, territory)) => {
                (language, Some(territory))
            }

            None => {
                (base, None)
            }
        };

    if let (
        Some(territory),
        Some(modifier),
    ) = (
        territory,
        modifier,
    ) {
        candidates.push(
            format!(
                "{language}_{territory}@{modifier}"
            )
        );
    }

    if let Some(territory) = territory {
        candidates.push(
            format!(
                "{language}_{territory}"
            )
        );
    }

    if let Some(modifier) = modifier {
        candidates.push(
            format!(
                "{language}@{modifier}"
            )
        );
    }

    if !language.is_empty() {
        candidates.push(
            language.to_string()
        );
    }

    candidates.dedup();

    candidates
}

fn localized_value(
    data: &DesktopEntryData,
    key: &str,
    locale_candidates: &[String],
) -> Option<String> {
    for locale in locale_candidates {
        let localized_key =
            format!(
                "{key}[{locale}]"
            );

        if let Some(value) =
            value(
                data,
                &localized_key,
            )
        {
            let value =
                unescape_desktop_value(
                    value,
                );

            if !value.is_empty() {
                return Some(value);
            }
        }
    }

    value(data, key)
        .map(unescape_desktop_value)
        .filter(|value| !value.is_empty())
}

fn unescape_desktop_value(
    value: &str,
) -> String {
    let mut output =
        String::with_capacity(
            value.len(),
        );

    let mut chars =
        value.chars();

    while let Some(ch) =
        chars.next()
    {
        if ch != '\\' {
            output.push(ch);
            continue;
        }

        match chars.next() {
            Some('s') => {
                output.push(' ');
            }

            Some('n') => {
                output.push('\n');
            }

            Some('t') => {
                output.push('\t');
            }

            Some('r') => {
                output.push('\r');
            }

            Some('\\') => {
                output.push('\\');
            }

            Some(next) => {
                output.push('\\');
                output.push(next);
            }

            None => {
                output.push('\\');
            }
        }
    }

    output
}

fn split_desktop_list(
    value: &str,
) -> Vec<String> {
    let mut items = Vec::new();
    let mut current = String::new();
    let mut escaped = false;

    for ch in value.chars() {
        if escaped {
            match ch {
                's' => {
                    current.push(' ');
                }

                'n' => {
                    current.push('\n');
                }

                't' => {
                    current.push('\t');
                }

                'r' => {
                    current.push('\r');
                }

                '\\' => {
                    current.push('\\');
                }

                ';' => {
                    current.push(';');
                }

                other => {
                    current.push('\\');
                    current.push(other);
                }
            }

            escaped = false;
            continue;
        }

        if ch == '\\' {
            escaped = true;
            continue;
        }

        if ch == ';' {
            let item =
                current.trim();

            if !item.is_empty() {
                items.push(
                    item.to_string(),
                );
            }

            current.clear();
            continue;
        }

        current.push(ch);
    }

    if escaped {
        current.push('\\');
    }

    let item =
        current.trim();

    if !item.is_empty() {
        items.push(
            item.to_string(),
        );
    }

    items
}

fn current_desktops() -> Vec<String> {
    env::var("XDG_CURRENT_DESKTOP")
        .unwrap_or_default()
        .split(':')
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(|value| {
            value.to_ascii_lowercase()
        })
        .collect()
}

fn desktop_environment_allows(
    data: &DesktopEntryData,
) -> bool {
    let current =
        current_desktops();

    if let Some(only_show_in) =
        value(
            data,
            "OnlyShowIn",
        )
    {
        let allowed =
            split_desktop_list(
                only_show_in,
            );

        if current.is_empty()
            || !allowed.iter().any(
                |desktop| {
                    current.iter().any(
                        |current| {
                            current
                                .eq_ignore_ascii_case(
                                    desktop,
                                )
                        },
                    )
                },
            )
        {
            return false;
        }
    }

    if let Some(not_show_in) =
        value(
            data,
            "NotShowIn",
        )
    {
        let blocked =
            split_desktop_list(
                not_show_in,
            );

        if blocked.iter().any(
            |desktop| {
                current.iter().any(
                    |current| {
                        current
                            .eq_ignore_ascii_case(
                                desktop,
                            )
                    },
                )
            },
        ) {
            return false;
        }
    }

    true
}

fn command_exists(
    program: &str,
) -> bool {
    let path =
        Path::new(program);

    if path.components().count() > 1 {
        return path.is_file();
    }

    let Some(path_var) =
        env::var_os("PATH")
    else {
        return false;
    };

    env::split_paths(
        &path_var,
    )
    .any(|dir| {
        dir.join(program).is_file()
    })
}

fn normalize_category(
    raw_categories: &[String],
) -> (String, String) {
    let has = |choices: &[&str]| {
        raw_categories.iter().any(|category| {
            choices.iter().any(|choice| {
                category.eq_ignore_ascii_case(choice)
            })
        })
    };

    if has(&[
        "Development",
        "IDE",
        "GUIDesigner",
        "WebDevelopment",
        "Building",
        "Debugger",
        "RevisionControl",
    ]) {
        return (
            "development".to_string(),
            "Development".to_string(),
        );
    }

    if has(&[
        "Network",
        "WebBrowser",
        "Email",
        "Chat",
        "InstantMessaging",
        "IRCClient",
        "Telephony",
        "RemoteAccess",
        "P2P",
        "FileTransfer",
        "News",
    ]) {
        return (
            "internet".to_string(),
            "Internet".to_string(),
        );
    }

    if has(&[
        "AudioVideo",
        "Audio",
        "Video",
        "Player",
        "Recorder",
        "Music",
        "Mixer",
        "TV",
        "Midi",
        "DiscBurning",
    ]) {
        return (
            "media".to_string(),
            "Media".to_string(),
        );
    }

    if has(&[
        "Graphics",
        "Photography",
        "RasterGraphics",
        "VectorGraphics",
        "2DGraphics",
        "3DGraphics",
        "Scanning",
        "OCR",
        "Publishing",
        "Viewer",
    ]) {
        return (
            "graphics".to_string(),
            "Graphics".to_string(),
        );
    }

    if has(&[
        "Office",
        "WordProcessor",
        "Spreadsheet",
        "Presentation",
        "Database",
        "Calendar",
        "ContactManagement",
        "Dictionary",
        "Chart",
        "Finance",
        "FlowChart",
        "PDA",
        "ProjectManagement",
    ]) {
        return (
            "office".to_string(),
            "Office".to_string(),
        );
    }

    if has(&[
        "Game",
        "ActionGame",
        "AdventureGame",
        "ArcadeGame",
        "BoardGame",
        "BlocksGame",
        "CardGame",
        "KidsGame",
        "LogicGame",
        "RolePlaying",
        "Shooter",
        "Simulation",
        "SportsGame",
        "StrategyGame",
    ]) {
        return (
            "games".to_string(),
            "Games".to_string(),
        );
    }

    if has(&[
        "TerminalEmulator",
        "TextEditor",
        "FileTools",
        "Calculator",
        "Clock",
        "Archiving",
        "Compression",
        "TextTools",
        "Utility",
    ]) {
        return (
            "utilities".to_string(),
            "Utilities".to_string(),
        );
    }

    if has(&[
        "System",
        "Settings",
        "Security",
        "Monitor",
        "PackageManager",
        "Filesystem",
        "Emulator",
        "HardwareSettings",
        "DesktopSettings",
    ]) {
        return (
            "system".to_string(),
            "System".to_string(),
        );
    }

    // --------------------------------------------------------
    // Unknown/new category
    // --------------------------------------------------------

    for category in raw_categories {
        if is_display_category(category) {
            return (
                category_to_id(category),
                category_to_name(category),
            );
        }
    }

    (
        "other".to_string(),
        "Other".to_string(),
    )
}

fn is_display_category(
    category: &str,
) -> bool {
    let ignored = [
        "GTK",
        "Qt",
        "KDE",
        "GNOME",
        "ConsoleOnly",
        "Core",
        "X-GNOME-Utilities",
        "X-GNOME-SystemSettings",
        "X-KDE-More",
    ];

    !category.is_empty()
        && !category.starts_with("X-")
        && !ignored.iter().any(|item| {
            category.eq_ignore_ascii_case(item)
        })
}

fn category_to_id(
    category: &str,
) -> String {
    let mut result =
        String::new();

    for ch in category.chars() {
        if ch.is_ascii_alphanumeric() {
            result.push(
                ch.to_ascii_lowercase()
            );
        } else if !result.ends_with('-') {
            result.push('-');
        }
    }

    result
        .trim_matches('-')
        .to_string()
}

fn category_to_name(
    category: &str,
) -> String {
    let mut result =
        String::new();

    let mut previous_lowercase =
        false;

    for ch in category.chars() {
        if ch == '-'
            || ch == '_'
        {
            result.push(' ');
            previous_lowercase = false;
            continue;
        }

        if ch.is_uppercase()
            && previous_lowercase
        {
            result.push(' ');
        }

        result.push(ch);

        previous_lowercase =
            ch.is_lowercase();
    }

    result
}

fn parse_app(
    id: String,
    path: &Path,
    data: DesktopEntryData,
    locale_candidates: &[String],
) -> Option<DiscoveredApp> {
    if value(
        &data,
        "Type",
    ) != Some("Application")
    {
        return None;
    }

    if desktop_bool(
        &data,
        "Hidden",
    ) || desktop_bool(
        &data,
        "NoDisplay",
    ) {
        return None;
    }

    if !desktop_environment_allows(
        &data,
    ) {
        return None;
    }

    if let Some(try_exec) =
        value(
            &data,
            "TryExec",
        )
    {
        let try_exec =
            unescape_desktop_value(
                try_exec,
            );

        if !try_exec.is_empty()
            && !command_exists(
                &try_exec,
            )
        {
            return None;
        }
    }

    let name =
        localized_value(
            &data,
            "Name",
            locale_candidates,
        )?;

    let exec =
        value(
            &data,
            "Exec",
        )
        .map(str::trim)
        .filter(|value| {
            !value.is_empty()
        })?
        .to_string();

    let generic_name =
        localized_value(
            &data,
            "GenericName",
            locale_candidates,
        );

    let comment =
        localized_value(
            &data,
            "Comment",
            locale_candidates,
        );

    let icon =
        value(
            &data,
            "Icon",
        )
        .map(
            unescape_desktop_value,
        )
        .filter(|value| {
            !value.is_empty()
        });

    let raw_categories =
        value(
            &data,
            "Categories",
        )
        .map(split_desktop_list)
        .unwrap_or_default();

    let keywords =
        localized_value(
            &data,
            "Keywords",
            locale_candidates,
        )
        .map(|value| {
            split_desktop_list(
                &value,
            )
        })
        .or_else(|| {
            value(
                &data,
                "Keywords",
            )
            .map(
                split_desktop_list,
            )
        })
        .unwrap_or_default();

    let (
        category_id,
        category_name,
    ) = normalize_category(
        &raw_categories,
    );

    Some(
        DiscoveredApp {
            app: AppEntry {
                id,
                name,
                generic_name,
                comment,
                icon,
                exec,
                terminal:
                    desktop_bool(
                        &data,
                        "Terminal",
                    ),
                category_id,
                category_name,
                keywords,
            },

            desktop_file:
                path.to_path_buf(),
        },
    )
}

fn discover_apps() -> Vec<DiscoveredApp> {
    let locale_candidates =
        locale_candidates();

    let mut apps =
        Vec::new();

    let mut claimed_ids =
        HashSet::<String>::new();

    for base in
        xdg_application_dirs()
    {
        if !base.is_dir() {
            continue;
        }

        let mut paths =
            WalkDir::new(
                &base,
            )
            .follow_links(true)
            .into_iter()
            .filter_map(
                Result::ok,
            )
            .filter(|entry| {
                entry
                    .file_type()
                    .is_file()
            })
            .map(|entry| {
                entry.into_path()
            })
            .filter(|path| {
                path.extension()
                    .and_then(|ext| {
                        ext.to_str()
                    })
                    == Some(
                        "desktop",
                    )
            })
            .collect::<Vec<_>>();

        paths.sort();

        for path in paths {
            let Some(id) =
                desktop_id(
                    &base,
                    &path,
                )
            else {
                continue;
            };

            if !claimed_ids.insert(
                id.clone(),
            ) {
                continue;
            }

            let Some(data) =
                parse_desktop_entry(
                    &path,
                )
            else {
                continue;
            };

            if let Some(app) =
                parse_app(
                    id,
                    &path,
                    data,
                    &locale_candidates,
                )
            {
                apps.push(app);
            }
        }
    }

    apps.sort_by(
        |a, b| {
            a.app
                .name
                .to_ascii_lowercase()
                .cmp(
                    &b.app
                        .name
                        .to_ascii_lowercase(),
                )
                .then_with(|| {
                    a.app
                        .id
                        .cmp(
                            &b.app.id,
                        )
                })
        },
    );

    apps
}

fn build_launcher_payload(
    apps: &[DiscoveredApp],
) -> LauncherPayload {
    let all_apps =
        apps
            .iter()
            .map(|item| {
                item.app.clone()
            })
            .collect::<Vec<_>>();

    let mut grouped:
        HashMap<String, (String, Vec<AppEntry>)> =
        HashMap::new();

    for item in apps {
        let app =
            item.app.clone();

        grouped
            .entry(
                app.category_id.clone(),
            )
            .or_insert_with(|| {
                (
                    app.category_name.clone(),
                    Vec::new(),
                )
            })
            .1
            .push(app);
    }

    let mut categories =
        grouped
            .into_iter()
            .map(
                |(
                    id,
                    (
                        name,
                        mut category_apps,
                    ),
                )| {
                    category_apps.sort_by(
                        |a, b| {
                            a.name
                                .to_ascii_lowercase()
                                .cmp(
                                    &b.name
                                        .to_ascii_lowercase(),
                                )
                        },
                    );

                    CategoryGroup {
                        id,
                        name,
                        count:
                            category_apps.len(),
                        apps:
                            category_apps,
                    }
                },
            )
            .collect::<Vec<_>>();

    categories.sort_by(
        |a, b| {
            a.name
                .to_ascii_lowercase()
                .cmp(
                    &b.name
                        .to_ascii_lowercase(),
                )
        },
    );

    categories.insert(
        0,
        CategoryGroup {
            id:
                "all".to_string(),

            name:
                "All".to_string(),

            count:
                all_apps.len(),

            apps:
                all_apps,
        },
    );

    LauncherPayload {
        total:
            apps.len(),

        categories,
    }
}

fn normalize_search_text(
    value: &str,
) -> String {
    value
        .trim()
        .to_ascii_lowercase()
}

fn subsequence_score(
    haystack: &str,
    needle: &str,
) -> Option<u32> {
    if needle.is_empty() {
        return Some(0);
    }

    let haystack_chars =
        haystack
            .chars()
            .collect::<Vec<_>>();

    let needle_chars =
        needle
            .chars()
            .collect::<Vec<_>>();

    let mut haystack_index =
        0usize;

    let mut first_match =
        None;

    let mut previous_match =
        None;

    let mut gaps =
        0u32;

    for needle_char in needle_chars {
        let mut found =
            None;

        while haystack_index
            < haystack_chars.len()
        {
            if haystack_chars[
                haystack_index
            ] == needle_char
            {
                found =
                    Some(
                        haystack_index,
                    );

                haystack_index += 1;

                break;
            }

            haystack_index += 1;
        }

        let index =
            found?;

        if first_match.is_none() {
            first_match =
                Some(index);
        }

        if let Some(previous) =
            previous_match
        {
            gaps +=
                index
                    .saturating_sub(
                        previous + 1,
                    )
                    as u32;
        }

        previous_match =
            Some(index);
    }

    Some(
        first_match
            .unwrap_or(0)
            as u32
            + gaps * 2,
    )
}

fn field_score(
    field: &str,
    token: &str,
    base: u32,
) -> Option<u32> {
    if field.is_empty() {
        return None;
    }

    if field == token {
        return Some(base);
    }

    if field.starts_with(token) {
        return Some(
            base + 5,
        );
    }

    if let Some(position) =
        field.find(token)
    {
        return Some(
            base
                + 15
                + position as u32,
        );
    }

    subsequence_score(
        field,
        token,
    )
    .map(|score| {
        base + 60 + score
    })
}

fn score_app(
    app: &AppEntry,
    query: &str,
) -> Option<u32> {
    let tokens =
        query
            .split_whitespace()
            .filter(|token| {
                !token.is_empty()
            })
            .collect::<Vec<_>>();

    if tokens.is_empty() {
        return Some(0);
    }

    let name =
        app.name
            .to_ascii_lowercase();

    let generic_name =
        app.generic_name
            .as_deref()
            .unwrap_or("")
            .to_ascii_lowercase();

    let comment =
        app.comment
            .as_deref()
            .unwrap_or("")
            .to_ascii_lowercase();

    let id =
        app.id
            .to_ascii_lowercase();

    let category =
        app.category_name
            .to_ascii_lowercase();

    let keywords =
        app.keywords
            .iter()
            .map(|keyword| {
                keyword
                    .to_ascii_lowercase()
            })
            .collect::<Vec<_>>();

    let mut total =
        0u32;

    for token in tokens {
        let mut best =
            field_score(
                &name,
                token,
                0,
            );

        for candidate in [
            field_score(
                &generic_name,
                token,
                20,
            ),

            field_score(
                &id,
                token,
                30,
            ),

            field_score(
                &category,
                token,
                40,
            ),

            field_score(
                &comment,
                token,
                50,
            ),
        ] {
            if let Some(candidate) =
                candidate
            {
                best =
                    Some(
                        best.map_or(
                            candidate,
                            |current| {
                                current
                                    .min(
                                        candidate,
                                    )
                            },
                        ),
                    );
            }
        }

        for keyword in
            &keywords
        {
            if let Some(candidate) =
                field_score(
                    keyword,
                    token,
                    25,
                )
            {
                best =
                    Some(
                        best.map_or(
                            candidate,
                            |current| {
                                current
                                    .min(
                                        candidate,
                                    )
                            },
                        ),
                    );
            }
        }

        total =
            total
                .saturating_add(
                    best?,
                );
    }

    Some(total)
}

fn find_app(
    id: &str,
) -> Option<DiscoveredApp> {
    discover_apps()
        .into_iter()
        .find(|item| {
            item.app.id == id
        })
}

fn shell_words(
    command: &str,
) -> Result<Vec<String>, String> {
    let mut words =
        Vec::new();

    let mut current =
        String::new();

    let mut in_single =
        false;

    let mut in_double =
        false;

    let mut escaped =
        false;

    for ch in command.chars() {
        if escaped {
            current.push(ch);
            escaped = false;
            continue;
        }

        match ch {
            '\\'
                if !in_single =>
            {
                escaped = true;
            }

            '\''
                if !in_double =>
            {
                in_single =
                    !in_single;
            }

            '"'
                if !in_single =>
            {
                in_double =
                    !in_double;
            }

            ' ' | '\t'
                if !in_single
                    && !in_double =>
            {
                if !current.is_empty() {
                    words.push(
                        std::mem::take(
                            &mut current,
                        ),
                    );
                }
            }

            _ => {
                current.push(ch);
            }
        }
    }

    if escaped
        || in_single
        || in_double
    {
        return Err(
            "Malformed Exec command"
                .to_string(),
        );
    }

    if !current.is_empty() {
        words.push(current);
    }

    Ok(words)
}

fn expand_exec_token(
    token: &str,
    app: &DiscoveredApp,
) -> Vec<String> {
    if token == "%i" {
        if let Some(icon) =
            &app.app.icon
        {
            return vec![
                "--icon"
                    .to_string(),

                icon.clone(),
            ];
        }

        return Vec::new();
    }

    if matches!(
        token,
        "%f"
            | "%F"
            | "%u"
            | "%U"
    ) {
        return Vec::new();
    }

    let mut output =
        String::new();

    let mut chars =
        token.chars();

    while let Some(ch) =
        chars.next()
    {
        if ch != '%' {
            output.push(ch);
            continue;
        }

        let Some(code) =
            chars.next()
        else {
            output.push('%');
            break;
        };

        match code {
            '%' => {
                output.push('%');
            }

            'c' => {
                output.push_str(
                    &app.app.name,
                );
            }

            'k' => {
                output.push_str(
                    &app
                        .desktop_file
                        .to_string_lossy(),
                );
            }

            'f'
            | 'F'
            | 'u'
            | 'U'
            | 'd'
            | 'D'
            | 'n'
            | 'N'
            | 'v'
            | 'm' =>
            {
            }

            'i' => {
                if let Some(icon) =
                    &app.app.icon
                {
                    output.push_str(
                        icon,
                    );
                }
            }

            _ => {}
        }
    }

    if output.is_empty() {
        Vec::new()
    } else {
        vec![output]
    }
}

fn expanded_exec(
    app: &DiscoveredApp,
) -> Result<Vec<String>, String> {
    let raw_words =
        shell_words(
            &app.app.exec,
        )?;

    let mut words =
        Vec::new();

    for token in raw_words {
        words.extend(
            expand_exec_token(
                &token,
                app,
            ),
        );
    }

    if words.is_empty() {
        Err(
            format!(
                "Invalid Exec command for {}",
                app.app.name
            ),
        )
    } else {
        Ok(words)
    }
}

fn terminal_command() -> Vec<String> {
    if let Ok(terminal) =
        env::var("TERMINAL")
    {
        if let Ok(words) =
            shell_words(
                &terminal,
            )
        {
            if !words.is_empty() {
                return words;
            }
        }
    }

    for candidate in [
        "kitty",
        "foot",
        "alacritty",
        "wezterm",
        "xterm",
    ] {
        if command_exists(candidate) {
            return vec![
                candidate.to_string(),
            ];
        }
    }

    vec![
        "kitty".to_string(),
    ]
}

fn terminal_exec_flag(
    program: &str,
) -> Option<&'static str> {
    let name =
        Path::new(program)
            .file_name()
            .and_then(|name| {
                name.to_str()
            })
            .unwrap_or(program);

    match name {
        "kitty"
        | "foot"
        | "alacritty"
        | "wezterm"
        | "xterm" =>
        {
            Some("-e")
        }

        _ => None,
    }
}

fn launch_with_exec(
    app: &DiscoveredApp,
) -> Result<(), String> {
    let words =
        expanded_exec(app)?;

    let program =
        &words[0];

    let mut arguments =
        words[1..].to_vec();

    if program.ends_with("btop") && !arguments.iter().any(|arg| arg == "--force-utf") {
        arguments.push("--force-utf".to_string());
    }

    let mut command =
        if app.app.terminal {
            let terminal =
                terminal_command();

            let mut command =
                Command::new(
                    &terminal[0],
                );

            if terminal.len() > 1 {
                command.args(
                    &terminal[1..],
                );
            }

            let app_class = app.app.name.to_lowercase();
            command.arg("--class").arg(&app_class);

            if let Some(flag) =
                terminal_exec_flag(
                    &terminal[0],
                )
            {
                command.arg(flag);
            }

            command
                .arg(program)
                .args(&arguments);

            command
        } else {
            let mut command =
                Command::new(
                    program,
                );

            command.args(
                &arguments,
            );

            command
        };

    let lang = env::var("LANG").unwrap_or_else(|_| "en_US.UTF-8".to_string());
    let lc_all = env::var("LC_ALL").unwrap_or_else(|_| "en_US.UTF-8".to_string());

    command
        .env("LANG", lang)
        .env("LC_ALL", lc_all)
        .stdin(
            Stdio::null(),
        )
        .stdout(
            Stdio::null(),
        )
        .stderr(
            Stdio::null(),
        )
        .spawn()
        .map(|_| ())
        .map_err(|error| {
            format!(
                "Failed to launch {}: {error}",
                app.app.name
            )
        })
}

fn launch_desktop_entry(
    app: &DiscoveredApp,
) -> Result<(), String> {
    if !app.app.terminal && command_exists("gio") {
        match Command::new("gio")
            .arg("launch")
            .arg(
                &app.desktop_file,
            )
            .stdin(
                Stdio::null(),
            )
            .stdout(
                Stdio::null(),
            )
            .stderr(
                Stdio::null(),
            )
            .status()
        {
            Ok(status)
                if status.success() =>
            {
                return Ok(());
            }

            _ => {}
        }
    }

    launch_with_exec(app)
}

fn print_json<T: Serialize>(
    value: &T,
) {
    match serde_json::to_string(
        value,
    ) {
        Ok(json) => {
            println!("{json}");
        }

        Err(error) => {
            eprintln!(
                "Failed to serialize launcher JSON: {error}"
            );
        }
    }
}

pub fn list() {
    let apps =
        discover_apps();

    let payload =
        build_launcher_payload(
            &apps,
        );

    print_json(
        &payload,
    );
}

pub fn search(
    query: &str,
) {
    let normalized_query =
        normalize_search_text(
            query,
        );

    if normalized_query.is_empty() {
        print_json(
            &SearchPayload {
                query:
                    String::new(),

                count:
                    0,

                results:
                    Vec::new(),
            },
        );

        return;
    }

    let mut ranked =
        discover_apps()
            .into_iter()
            .filter_map(|item| {
                score_app(
                    &item.app,
                    &normalized_query,
                )
                .map(|score| {
                    (
                        score,
                        item.app,
                    )
                })
            })
            .collect::<Vec<_>>();

    ranked.sort_by(
        |(
            score_a,
            app_a,
        ),
         (
            score_b,
            app_b,
        )| {
            score_a
                .cmp(
                    score_b,
                )
                .then_with(|| {
                    app_a
                        .name
                        .to_ascii_lowercase()
                        .cmp(
                            &app_b
                                .name
                                .to_ascii_lowercase(),
                        )
                })
                .then_with(|| {
                    app_a
                        .id
                        .cmp(
                            &app_b.id,
                        )
                })
        },
    );

    let results =
        ranked
            .into_iter()
            .map(|(_, app)| app)
            .collect::<Vec<_>>();

    print_json(
        &SearchPayload {
            query:
                query
                    .trim()
                    .to_string(),

            count:
                results.len(),

            results,
        },
    );
}

pub fn launch(
    id: &str,
) {
    let Some(app) =
        find_app(id)
    else {
        print_json(
            &ActionResponse {
                success:
                    false,

                action:
                    "launch",

                id:
                    Some(
                        id.to_string(),
                    ),

                message:
                    format!(
                        "Application not found: {id}"
                    ),
            },
        );

        return;
    };

    match launch_desktop_entry(
        &app,
    ) {
        Ok(()) => {
            print_json(
                &ActionResponse {
                    success:
                        true,

                    action:
                        "launch",

                    id:
                        Some(
                            app.app
                                .id
                                .clone(),
                        ),

                    message:
                        format!(
                            "Launched {}",
                            app.app.name
                        ),
                },
            );
        }

        Err(error) => {
            print_json(
                &ActionResponse {
                    success:
                        false,

                    action:
                        "launch",

                    id:
                        Some(
                            app.app
                                .id
                                .clone(),
                        ),

                    message:
                        error,
                },
            );
        }
    }
}

pub fn refresh() {
    let apps =
        discover_apps();

    print_json(
        &ActionResponse {
            success:
                true,

            action:
                "refresh",

            id:
                None,

            message:
                format!(
                    "Discovered {} applications",
                    apps.len()
                ),
        },
    );
}

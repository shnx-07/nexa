pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    property int _stateTrigger: 0

    Instantiator {
        model: Mpris.players.values
        delegate: Connections {
            target: modelData
            function onPlaybackStateChanged() { root._stateTrigger++ }
            function onTrackTitleChanged() { root._stateTrigger++ }
            function onTrackArtistChanged() { root._stateTrigger++ }
            function onTrackArtUrlChanged() { root._stateTrigger++ }
        }
    }

    readonly property var activePlayer: {
        root._stateTrigger;
        const players = Mpris.players.values;
        if (!players || players.length === 0) return null;
        for (let i = 0; i < players.length; i++) {
            if (players[i] && players[i].playbackState === MprisPlaybackState.Playing)
                return players[i];
        }
        return players[0];
    }

    readonly property bool isPlaying: {
        root._stateTrigger;
        return activePlayer !== null && activePlayer.playbackState === MprisPlaybackState.Playing;
    }
    readonly property string title: {
        root._stateTrigger;
        return activePlayer ? (activePlayer.trackTitle || "") : "";
    }
    readonly property string artist: {
        root._stateTrigger;
        return activePlayer ? (activePlayer.trackArtist || "") : "";
    }
    readonly property string artUrl: {
        root._stateTrigger;
        return activePlayer ? (activePlayer.trackArtUrl || "") : "";
    }

    function playPause() {
        if (activePlayer && activePlayer.canTogglePlaying)
            activePlayer.togglePlaying();
    }

    function previous() {
        if (activePlayer && activePlayer.canGoPrevious)
            activePlayer.previous();
    }

    function next() {
        if (activePlayer && activePlayer.canGoNext)
            activePlayer.next();
    }
}

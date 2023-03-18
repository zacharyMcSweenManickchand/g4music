namespace G4 {

    [DBus (name = "org.mpris.MediaPlayer2.Player")]
    public class MprisPlayer : Object {
        [DBus (visible = false)]
        private unowned Application _app;
        private unowned DBusConnection _connection;

        public MprisPlayer (Application app, DBusConnection connection) {
            _app = app;
            _connection = connection;

            app.index_changed.connect (on_index_changed);
            app.music_changed.connect (on_music_changed);
            app.music_tag_parsed.connect (on_music_tag_parsed);
            app.player.state_changed.connect (on_state_changed);
        }

        public bool can_go_next {
            get {
                return _app.current_item < (int) _app.music_list.get_n_items () - 1;
            }
        }

        public bool can_go_previous {
            get {
                return _app.current_item > 0;
            }
        }

        public bool can_play {
            get {
                return _app.music_list.get_n_items () > 0;
            }
        }

        public void next () throws Error {
            _app.play_next ();
        }

        public void previous () throws Error {
            _app.play_previous ();
        }

        public void play_pause () throws Error {
            _app.play_pause();
        }

        private void on_index_changed (int index, uint size) {
            var builder = new VariantBuilder (new VariantType ("a{sv}"));
            builder.add ("{sv}", "CanGoNext", new Variant.boolean (index < (int) size - 1));
            builder.add ("{sv}", "CanGoPrevious", new Variant.boolean (index > 0));
            builder.add ("{sv}", "CanPlay", new Variant.boolean (size > 0));
            send_properties (builder);
        }

        private void on_music_changed (Music music) {
            send_meta_data (music);
        }

        private void on_music_tag_parsed (Music music, Gst.Sample? image) {
            send_meta_data (music);
        }

        private void on_state_changed (Gst.State state) {
            string st;
            switch (state) {
                case Gst.State.PLAYING:
                    st = "Playing";
                    break;
                case Gst.State.PAUSED:
                    st = "Paused";
                    break;
                default:
                    st = "Stopped";
                    break;
            }
            send_property ("PlaybackStatus", new Variant.string (st));
        }

        internal void send_meta_data (Music music, string? art_uri = null) {
            var dict = new VariantDict (null);
            var artists = new VariantBuilder (new VariantType ("as"));
            artists.add ("s", music.artist);
            dict.insert ("xesam:artist", "as", artists);
            dict.insert ("xesam:title", "s", music.title);
            if (art_uri != null) {
                dict.insert ("mpris:artUrl", "s", (!)art_uri);
            }
            send_property ("Metadata", dict.end ());
        }

        private void send_property (string name, Variant variant) {
            var builder = new VariantBuilder (new VariantType ("a{sv}"));
            builder.add ("{sv}", name, variant);
            send_properties (builder);
        }

        private void send_properties (VariantBuilder builder) {
            var invalid = new VariantBuilder (new VariantType ("as"));
            try {
                _connection.emit_signal (
                    null,
                    "/org/mpris/MediaPlayer2",
                    "org.freedesktop.DBus.Properties",
                    "PropertiesChanged",
                    new Variant (
                        "(sa{sv}as)",
                        "org.mpris.MediaPlayer2.Player",
                        builder,
                        invalid
                    )
                );
            } catch (Error e) {
                warning ("Send MPRIS failed: %s\n", e.message);
            }
        }
    }

    [DBus (name = "org.mpris.MediaPlayer2")]
    public class MprisRoot : Object {
        private unowned Application _app;

        public MprisRoot (Application app) {
            _app = app;
        }

        public bool can_quit {
            get {
                return true;
            }
        }

        public bool can_raise {
            get {
                return true;
            }
        }

        public bool has_track_list {
            get {
                return false;
            }
        }

        public string desktop_entry {
            get {
                return _app.application_id;
            }
        }

        public string identity {
            get {
                return _app.application_id;
            }
        }

        public string[] supported_uri_schemes {
            owned get {
                return {"file", "smb"};
            }
        }

        public string[] supported_mime_types {
            owned get {
                return {"audio/*"};
            }
        }

        public void quit () throws Error {
            _app.quit ();
        }

        public void raise () throws Error {
            _app.activate ();
        }
    }
}
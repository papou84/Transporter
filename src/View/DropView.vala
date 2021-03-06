using Gtk;
using Gdk;

public class DropView : AbstractView {

    private const Gtk.TargetEntry[] targets = {
          {"text/uri-list",0,0}
    };
    private const string DRAG_TEXT = _("Drag files and folders here");
    private const string DROP_TEXT = _("Drop to send");

    private Gtk.Label title;

    construct {
        border_width = 10;

        var drop = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        drop.hexpand = true;
        drop.vexpand = true;
        drop.get_style_context ().add_class ("drop");

        title = new Gtk.Label (DRAG_TEXT);
        title.get_style_context ().add_class ("h2");
        title.hexpand = true;
        title.vexpand = true;
        drop.add (title);

        add (drop);
        show_all ();

        Gtk.drag_dest_set (this, Gtk.DestDefaults.ALL, targets, Gdk.DragAction.COPY);
        drag_motion.connect (this.on_drag_motion);
        drag_leave.connect (this.on_drag_leave);
        drag_data_received.connect (this.on_drag_data_received);
    }

    public DropView(TransporterWindow window){
        base (window);
    }

    private bool on_drag_motion (DragContext context, int x, int y, uint time){
        title.label = DROP_TEXT;
        return false;
    }

    private void on_drag_leave (DragContext context, uint time) {
        title.label = DRAG_TEXT;
    }

    private void on_drag_data_received (Gdk.DragContext drag_context, int x, int y, Gtk.SelectionData data, uint info, uint time){
        Gtk.drag_finish (drag_context, true, false, time);

        string[] paths = {};
        var uris = data.get_uris ();
        foreach (var uri in uris) {
            try{
                var path = GLib.Filename.from_uri(uri);
                paths += path;
            }
            catch(GLib.ConvertError e){
                warning (e.message);
            }
        }

        send (paths);
    }

    public void send(string[] paths){
        var display = window.get_display ();
        var clipboard = Gtk.Clipboard.get_for_display (display, Gdk.SELECTION_CLIPBOARD);
        window.back ();
        window.append (new SendView (window, clipboard));

        Utils.paths = paths;
        try{
            if(Thread.supported ()){
                new Thread<bool>.try ("PackThread", () => {
                    var path = Utils.get_send_path ();
                    wormhole.send (path);
                    return false;
                });
            }
            else{
                var path = Utils.get_send_path ();
                wormhole.send (path);
            }
        }
        catch(Error e){
            warning (e.message);
            wormhole.errored (e.message, _("Internal Error"), true);
        }
    }

}

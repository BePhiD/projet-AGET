#= 
Visu pour le système de création automatique d'emploi du temps (écrit en julia)
Auteur : Philippe Belhomme
Dates de création : vendredi 26 août 2022
  de modification : vendredi 26 août 2022
=#

using Gtk
# Put your GUI code here
win = GtkWindow("My First Gtk.jl Program", 400, 200)

b = GtkButton("Click Me")
push!(win,b)

function on_button_clicked(w)
  println("The button has been clicked")
end
signal_connect(on_button_clicked, b, "clicked")

showall(win)

#= Code nécessaire pour que la fenêtre ne se referme pas aussitôt après la
commande : showall(win)  =#
if !isinteractive()
    c = Condition()
    signal_connect(win, :destroy) do widget
        notify(c)
    end
    @async Gtk.gtk_main()
    wait(c)
end
using Genie
import Genie.Router: route
import Genie.Renderer.Json: json

Genie.config.run_as_server = true

route("/") do
  #=(:message => "Philippe, OK",
   :toto => "12345") |> json =#
   json( Dict("width" => 20,"height" => 30) );

end

Genie.startup()
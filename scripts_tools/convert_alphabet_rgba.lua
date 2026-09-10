local spr = Sprite{ fromFile = "assets/sprites/ui/alphabet.png" }
app.command.ChangePixelFormat{ format = "rgb" }
spr:saveAs("assets/sprites/ui/alphabet.png")

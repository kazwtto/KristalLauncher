return {
  version = "1.11",
  luaversion = "5.1",
  tiledversion = "1.11.2",
  class = "",
  orientation = "orthogonal",
  renderorder = "right-down",
  width = 25,
  height = 12,
  tilewidth = 40,
  tileheight = 40,
  nextlayerid = 7,
  nextobjectid = 16,
  properties = {
    ["border"] = "tvblack",
  },
  tilesets = {},
  layers = {
    {
      type = "imagelayer",
      image = "../../../../assets/sprites/tilesets/consoleroombg.png",
      id = 2,
      name = "Image 1",
      class = "",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      repeatx = false,
      repeaty = false,
      properties = {}
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 3,
      name = "collision",
      class = "",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      objects = {
        {
          id = 2,
          name = "",
          type = "",
          shape = "rectangle",
          x = -24.7051,
          y = 331.978,
          width = 1024.73,
          height = 40,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 3,
          name = "",
          type = "",
          shape = "rectangle",
          x = -26.0149,
          y = 418.005,
          width = 1026.73,
          height = 40,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 4,
          name = "",
          type = "",
          shape = "rectangle",
          x = 420.159,
          y = 458.017,
          width = 40,
          height = 62,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 5,
          name = "",
          type = "",
          shape = "rectangle",
          x = 520.176,
          y = 418.005,
          width = 480.116,
          height = 40,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 6,
          name = "",
          type = "",
          shape = "rectangle",
          x = 520.176,
          y = 458.013,
          width = 40,
          height = 62,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 7,
          name = "",
          type = "",
          shape = "rectangle",
          x = 960.123,
          y = 370.575,
          width = 40,
          height = 47.3434,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 8,
          name = "",
          type = "",
          shape = "rectangle",
          x = -63.446,
          y = 370.711,
          width = 40,
          height = 47.5455,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 8,
          name = "",
          type = "",
          shape = "rectangle",
          x = 33.446,
          y = 370.711,
          width = 40,
          height = 47.5455,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 9,
          name = "",
          type = "",
          shape = "rectangle",
          x = 459.985,
          y = 520.005,
          width = 60.1818,
          height = 40,
          rotation = 0,
          visible = true,
          properties = {}
        }
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 4,
      name = "markers",
      class = "",
      visible = false,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      objects = {
        {
          id = 10,
          name = "spawn",
          type = "",
          shape = "point",
          x = 490,
          y = 400,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {}
        }
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 6,
      name = "objects",
      class = "",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      objects = {
        {
          id = 8,
          name = "script",
          type = "",
          shape = "rectangle",
          x = 36,
          y = 370.711,
          width = 40,
          height = 47.5455,
          rotation = 0,
          visible = true,
          properties = {
            ["cutscene"] = "ramb_ending.nowayback",
            ["once"] = false
          }
        },
        {
          id = 11,
          name = "interactable",
          type = "",
          shape = "rectangle",
          x = 726.33,
          y = 331.625,
          width = 43.608,
          height = 40.125,
          rotation = 0,
          visible = true,
          properties = {
            ["text"] = "* (É o verso de um papel.\n\"ATO 3\" está rabiscado em vermelho no topo.)"
          }
        },
        {
          id = 13,
          name = "interactable",
          type = "",
          shape = "rectangle",
          x = 273.5,
          y = 331.5,
          width = 380,
          height = 40,
          rotation = 0,
          visible = true,
          properties = {
            ["text1"] = "* (É um console de videogame. Parece ser onde todos os personagens do tabuleiro jogam.)",
            ["text2"] = "* (Os controles e o console estão trancados estilo consultório de dentista.)"
          }
        },
        {
          id = 15,
          name = "interactable",
          type = "",
          shape = "rectangle",
          x = 885.196,
          y = 372.271,
          width = 51.608,
          height = 40.125,
          rotation = 0,
          visible = true,
          properties = {
            ["cutscene"] = "ramb_ending.manhole",
            ["once"] = false
          }
        }
      }
    },
    {
      type = "imagelayer",
      image = "../../../../assets/sprites/tilesets/curtain.png",
      id = 5,
      name = "Image 2",
      class = "",
      visible = true,
      opacity = 1,
      offsetx = 839.019,
      offsety = 249.98,
      parallaxx = 1,
      parallaxy = 1,
      repeatx = false,
      repeaty = false,
      properties = {}
    }
  }
}

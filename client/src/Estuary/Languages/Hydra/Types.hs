module Estuary.Languages.Hydra.Types where

import Data.Text (Text)

data Parameters =
  Parameters [Double] | -- [0.2,0.4] -- [0.3,0.4,1.0]
  Fast [Double] Parameters | -- [].fast(1.5)
  Smooth [Double] Parameters -- [].smooth(1.5) -- [].fast().smooth()
  deriving (Show)

data Source =
  Osc [Parameters] |
  Solid [Parameters] |
  Gradient [Parameters] |
  Noise [Parameters] |
  Shape [Parameters] |
  Voronoi [Parameters] |
  OutputAsSource Output |
  Src Source [Parameters] |
  InputAsSource Input |
  Brightness [Parameters] Source |
  Contrast [Parameters] Source |
  Colorama [Parameters] Source |
  Color [Parameters] Source |
  Invert [Parameters] Source |
  Luma [Parameters] Source |
  Hue [Parameters] Source |
  Posterize [Parameters] Source |
  Saturate [Parameters] Source |
  Shift [Parameters] Source |
  Thresh [Parameters] Source |
  Kaleid [Parameters] Source |
  Pixelate [Parameters] Source |
  Repeat [Parameters] Source |
  RepeatX [Parameters] Source |
  RepeatY [Parameters] Source |
  Rotate [Parameters] Source |
  Scale [Parameters] Source |
  Scroll [Parameters] Source |
  ScrollX [Parameters] Source |
  ScrollY [Parameters] Source |
  Modulate Source [Parameters] Source |
  ModulateHue Source [Parameters] Source |
  ModulateKaleid Source [Parameters] Source |
  ModulatePixelate Source [Parameters] Source |
  ModulateRepeat Source [Parameters] Source |
  ModulateRepeatX Source [Parameters] Source |
  ModulateRepeatY Source [Parameters] Source |
  ModulateRotate Source [Parameters] Source |
  ModulateScale Source [Parameters] Source |
  ModulateScrollX Source [Parameters] Source |
  ModulateScrollY Source [Parameters] Source |
  Add Source [Parameters] Source |
  Mult Source [Parameters] Source |
  Blend Source [Parameters] Source |
  Diff Source [Parameters] Source |
  Layer Source [Parameters] Source |
  Mask Source [Parameters] Source
  deriving (Show)

data Input =
  S0 |
  S1 |
  S2 |
  S3 |
  OutputasInput Output
  deriving (Show)

data Output =
  O0 |
  O1 |
  O2 |
  O3 |
  All
  deriving (Show)

data Statement =
  InitScreen Input [Parameters] | --s0.InitScreen()
  InitCam Input [Parameters] | --s0.InitCam(), s0.InitCam(1)
  InitVideo Input Text | --s0.initVideo(url)
  InitImage Input Text | --s0.initImage(url)
  Out Source Output | --solid().out()
  Render (Maybe Output) | --render(o2)
  Speed Parameters | -- speed = 1.5
  SetResolution [Parameters] -- setResolution(w,h)
  deriving (Show)

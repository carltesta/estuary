module Estuary.Types.Hint where

import Data.Text (Text)
import Data.Maybe (mapMaybe)

import Estuary.Types.Tempo
import Estuary.Utility
import Estuary.Types.Definition
import Estuary.Types.TranslatableText


data Hint =
  SampleHint Text |
  LogMessage TranslatableText |
  SetGlobalDelayTime Double |
  SilenceHint |
  ZoneHint Int Definition |
  ToggleTerminal |
  ToggleSidebar |
  ToggleStats |
  ToggleHeader |
  CanvasActive Bool 
  deriving (Eq,Show)

justGlobalDelayTime :: [Hint] -> Maybe Double
justGlobalDelayTime = lastOrNothing . mapMaybe f
  where f (SetGlobalDelayTime x) = Just x
        f _ = Nothing

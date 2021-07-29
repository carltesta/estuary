{-# LANGUAGE OverloadedStrings #-}
module Estuary.Help.Saludos where

import Reflex
import Reflex.Dom
import Data.Text
import GHCJS.DOM.EventM
import Estuary.Widgets.Reflex
import Estuary.Widgets.Reflex

--render multiple sub-help files
saludosHelpFile :: MonadWidget t m => m ()
saludosHelpFile = divClass "languageHelpContainer" $ divClass "languageHelp" $ do
  about
  functionRef "hola"
  functionRef "cómo estas"
  functionRef "saludos"
  functionRef "que tal"
  functionRef "todo bien"
  return ()


-- about
about :: MonadWidget t m => m ()
about = do
 divClass "about primary-color code-font" $ text "Saludos"
 divClass "about primary-color code-font" $ text "A mini live coding esolang developed in Bogotá, Colombia."

exampleText :: Text -> Text

exampleText "hola" = "¡hola!"
exampleText "cómo estas" = "¡cómo estas!"
exampleText "saludos" = "¡saludos!"
exampleText "que tal" = "¡hola! que tal"
exampleText "todo bien" =  "¡saludos! todo bien 2"

referenceText :: Text -> Text

referenceText "hola" = "returns Dirt's \"moog\" sample"
referenceText "cómo estas" = "returns Dirt's \"arpy\" sample"
referenceText "saludos" = "returns Dirt's \"bd\" sample"
referenceText "que tal" =  "returns TidalCycles' brak"
referenceText "todo bien" =  "returns TidalCycles' chop"

-- help files for samples
functionRef :: MonadWidget t m => Text -> m ()
functionRef x = divClass "helpWrapper" $ do
 switchToReference <- buttonWithClass' x
 exampleVisible <- toggle True switchToReference
 referenceVisible <- toggle False switchToReference
 hideableWidget exampleVisible "exampleText primary-color code-font" $ text (exampleText x)
 hideableWidget referenceVisible "referenceText code-font" $ text (referenceText x)
 return ()

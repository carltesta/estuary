{-# LANGUAGE OverloadedStrings #-}
module Estuary.Help.Natural where

import Reflex
import Reflex.Dom
import Data.Text
import GHCJS.DOM.EventM
import Estuary.Widgets.Reflex
import Data.Map
import Estuary.Widgets.Reflex


--render multiple sub-help files
naturalHelpFile :: MonadWidget t m => m ()
naturalHelpFile = divClass "languageHelpContainer" $ divClass "languageHelp" $ do
  about
  functionRef"El cóndor"
  functionRef "El hombre"
  functionRef "El león"
  functionRef "vuela"
  functionRef "caza"
  functionRef "ruge"
  return ()

  -- about
about :: MonadWidget t m => m ()
about = do
  divClass "about primary-color code-font" $ text "Natural"
  divClass "about primary-color code-font" $ text "A mini live coding esolang developed in Manizales, Colombia."

exampleText :: Text -> Text

exampleText "El cóndor" = "El cóndor"
exampleText "El hombre" = "El hombre"
exampleText "El león" = "El león"
exampleText "vuela" = "El cóndor vuela agitado 10"
exampleText "caza" =  "El hombre caza 2"
exampleText "ruge" =  "El leon ruge 0.5"

referenceText :: Text -> Text

referenceText "El cóndor" = "returns Dirt's \"sax\" sample"
referenceText "El hombre" = "returns Dirt's \"pluck\" sample"
referenceText "El león" = "returns Dirt's \"bass\" sample"
referenceText "vuela" =  "returns TidalCycles' fast"
referenceText "caza" =  "returns TidalCycles' striate"
referenceText "ruge" =  "returns TidalCycles' slow"

functionRef :: MonadWidget t m => Text -> m ()
functionRef x = divClass "helpWrapper" $ do
  switchToReference <- buttonWithClass' x
  exampleVisible <- toggle True switchToReference
  referenceVisible <- toggle False switchToReference
  hideableWidget exampleVisible "exampleText primary-color code-font" $ text (exampleText x)
  hideableWidget referenceVisible "referenceText code-font" $ text (referenceText x)
  return ()

{-# LANGUAGE OverloadedStrings #-}
module Estuary.Help.LaCalle where

import Reflex
import Reflex.Dom
import Data.Text
import GHCJS.DOM.EventM
import Estuary.Widgets.Reflex
import Estuary.Widgets.Reflex


-- import Estuary.Types.Language

--render multiple sub-help files
laCalleHelpFile :: MonadWidget t m => m ()
laCalleHelpFile = divClass "languageHelpContainer" $ divClass "languageHelp" $ do
    about
    holaChoche
    unasChelas
    miGerma
    vamosA
    bienHelenas
    paltaConEl
    miCerro
    return ()


-- about
about :: MonadWidget t m => m ()
about = do
  divClass "about primary-color code-font" $ text "LaCalle reference"
  divClass "about primary-color code-font" $ text "A mini live coding esolang developed in Lima (Peru) by Ivanka Cotrina, using slang characteristic of that city’s working-class neighbourhoods."



-- help files for samples
holaChoche :: MonadWidget t m => m ()
holaChoche = divClass "helpWrapper" $ do
   switchToReference <- divClass "code-font primary-color reference-button" $ button "hola Choche:"
   exampleVisible <- toggle True switchToReference
   referenceVisible <- toggle False switchToReference
   hideableWidget exampleVisible "exampleText primary-color code-font" $ text "\"hola choche\"" --languageHelpWidget MiniTidal
   hideableWidget referenceVisible "referenceText code-font" $ text "is slang for 'hi friend' and translates to the Tidal sample 'sitar'." --languageHelpWidget MiniTidal
   return ()


   -- help files for samples
unasChelas :: MonadWidget t m => m ()
unasChelas = divClass "helpWrapper" $ do
   switchToReference <- divClass "code-font primary-color reference-button" $ button "unas chelas:"
   exampleVisible <- toggle True switchToReference
   referenceVisible <- toggle False switchToReference
   hideableWidget exampleVisible "exampleText primary-color code-font" $ text "\"unas chelas\"" --languageHelpWidget MiniTidal
   hideableWidget referenceVisible "referenceText code-font" $ text "is slang for 'some beers' and translates to the Tidal sample 'ifdrums'." --languageHelpWidget MiniTidal
   return ()


   -- help files for samples
miGerma :: MonadWidget t m => m ()
miGerma = divClass "helpWrapper" $ do
   switchToReference <- divClass "code-font primary-color reference-button" $ button "mi germa:"
   exampleVisible <- toggle True switchToReference
   referenceVisible <- toggle False switchToReference
   hideableWidget exampleVisible "exampleText primary-color code-font" $ text "\"mi germa\"" --languageHelpWidget MiniTidal
   hideableWidget referenceVisible "referenceText code-font" $ text "is slang for 'my girlfriend' and translates to the Tidal sample 'metal'." --languageHelpWidget MiniTidal
   return ()


   -- help files for samples
vamosA :: MonadWidget t m => m ()
vamosA = divClass "helpWrapper" $ do
   switchToReference <- divClass "code-font primary-color reference-button" $ button "vamos a:"
   exampleVisible <- toggle True switchToReference
   referenceVisible <- toggle False switchToReference
   hideableWidget exampleVisible "exampleText primary-color code-font" $ text "\"vamos a\"" --languageHelpWidget MiniTidal
   hideableWidget referenceVisible "referenceText code-font" $ text "is slang for 'go to somewhere' and translates to the Tidal sample 'casio'." --languageHelpWidget MiniTidal
   return ()


-- help files for functions
tuManyas :: MonadWidget t m => m ()
tuManyas = divClass "helpWrapper" $ do
   switchToReference <- divClass "code-font primary-color reference-button" $ button "tu manyas:"
   exampleVisible <- toggle True switchToReference
   referenceVisible <- toggle False switchToReference
   hideableWidget exampleVisible "exampleText primary-color code-font" $ text "\"hola choche\" tu manyas 2" --languageHelpWidget MiniTidal
   hideableWidget referenceVisible "referenceText code-font" $ text "is slang for 'you know' and translates to the Tidal function 'slow'." --languageHelpWidget MiniTidal
   return ()


-- help files for functions
bienHelenas :: MonadWidget t m => m ()
bienHelenas = divClass "helpWrapper" $ do
   switchToReference <- divClass "code-font primary-color reference-button" $ button "bien helenas:"
   exampleVisible <- toggle True switchToReference
   referenceVisible <- toggle False switchToReference
   hideableWidget exampleVisible "exampleText primary-color code-font" $ text "\"unas chelas\" bien helenas 0.5" --languageHelpWidget MiniTidal
   hideableWidget referenceVisible "referenceText code-font" $ text "is slang for 'frozen/very cold' and translates to the Tidal function 'delay'." --languageHelpWidget MiniTidal
   return ()


-- help files for functions
paltaConEl :: MonadWidget t m => m ()
paltaConEl = divClass "helpWrapper" $ do
   switchToReference <- divClass "code-font primary-color reference-button" $ button "palta con el:"
   exampleVisible <- toggle True switchToReference
   referenceVisible <- toggle False switchToReference
   hideableWidget exampleVisible "exampleText primary-color code-font" $ text "\"mi germa\" palta con el 4" --languageHelpWidget MiniTidal
   hideableWidget referenceVisible "referenceText code-font" $ text "is slang for 'what a shame' and translates to the Tidal function 'iter'." --languageHelpWidget MiniTidal
   return ()


-- help files for functions
miCerro :: MonadWidget t m => m ()
miCerro = divClass "helpWrapper" $ do
   switchToReference <- divClass "code-font primary-color reference-button" $ button "mi cerro:"
   exampleVisible <- toggle True switchToReference
   referenceVisible <- toggle False switchToReference
   hideableWidget exampleVisible "exampleText primary-color code-font" $ text "\"vamos a\" mi cerro" --languageHelpWidget MiniTidal
   hideableWidget referenceVisible "referenceText code-font" $ text "is slang for 'my neighborhood (a peripheral place)' and translates to the Tidal function 'chop'." --languageHelpWidget MiniTidal
   return ()

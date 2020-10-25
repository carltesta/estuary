{-# LANGUAGE OverloadedStrings #-}
module Estuary.Help.Hydra where

import Reflex hiding (Request,Response)
import Reflex.Dom hiding (Request,Response)

import Estuary.Types.Context
import Estuary.Types.Language
import Estuary.Reflex.Utility
import Estuary.Widgets.Editor
import Data.Map.Strict


hydraHelp :: MonadWidget t m => Editor t m ()
hydraHelp = el "div" $ do
  aboutHydra
  examplesHydra
  notWorkingFunctionsHydra


aboutHydra :: MonadWidget t m => Editor t m ()
aboutHydra = elClass "div" "infoRef" $ do
  dynText =<< (translatableText $ fromList [
    (English,"Hydra is a live coding platform for visual synthesis based on analog video synthesizers. Hydra is an open-source project developed by Olivia Jack. You can access a standalone version of Hydra (separate from Estuary) as well as further documentation and examples here: https://hydra.ojack.xyz/."),
    (Español,"Hydra es una plataforma de live coding para síntesis visual basado en visuales generados por sintetizadores análogos. Hydra es un proyecto open-source desarrollado por Olivia Jack. Para una versión standalone de Hydra (separada de Estuary), así como más documentación y ejemplos, accede aquí: https://hydra.ojack.xyz/.")
    ])


examplesHydra :: MonadWidget t m => Editor t m ()
examplesHydra = el "div" $ do
  dynText =<< (translatableText $ fromList [
    (English,"Examples:"),
    (Español,"Ejemplos:")
    ])
  el "ul" $ do
    el "li" $ elClass "div" "ieRef" $ text "shape([3,4,5,6].smooth()).repeat(20).kaleid().modulateScale(o0,0.2,0.5).out()"
    el "li" $ elClass "div" "ieRef" $ text "osc(10, -5, [0.4,0.9].smooth()).modulateRotate(o0, [1.5,2.5,3.5].fast(3).smooth()).out(o0)"


notWorkingFunctionsHydra :: MonadWidget t m => Editor t m ()
notWorkingFunctionsHydra = el "div" $ do
  dynText =<< (translatableText $ fromList [
    (English,"Estuary currently has partial access to Hydra functionality. The idioms below are currently unavailable (although all will eventually be available within Estuary)."),
    (Español,"Hoy por hoy, Estuary tiene una versión de Hydra con funcionalidad parcial. Las siguientes expresiones no están actualmente disponibles (aunque estarán eventualmente disponibles dentro de Estuary)")
    ])
  el "ul" $ do
    el "li" $ dynText =<< (translatableText $ fromList [
      (English,"External source-input functions (video, image, screen, camera), i.e."),
      (Español,"Funciones para entradas de fuentes externas (video, imagen, captura de pantalla, cámara), ej.")
      ])
    el "div" $ elClass "div" "ieRef" $ text "s0.initScreen()"
    el "div" $ elClass "div" "ieRef" $ text "scr(s0)"
    el "li" $ dynText =<< (translatableText $ fromList [
      (English,"Anonymous functions as parameters, i.e."),
      (Español,"Funciones anónimas como parámetros, ej.")
      ])
    el "div" $ elClass "div" "ieRef" $ text "() => mouse.x"
    el "div" $ elClass "div" "ieRef" $ text "({time}) => time%360"
    el "li" $ dynText =<< (translatableText $ fromList [
      (English,"Audio functions, i.e."),
      (Español,"Funciones de audio, ej.")
      ])
    el "div" $ elClass "div" "ieRef" $ text "a.show()"
    el "div" $ elClass "div" "ieRef" $ text "()=>a.fft[1]"
    el "li" $ dynText =<< (translatableText $ fromList [
      (English,"Division of screen into 4 when rendering the four different outputs, i.e."),
      (Español,"División de la pantalla en 4 cuando se renderizan los cuatro diferentes salidas, ej.")
      ])

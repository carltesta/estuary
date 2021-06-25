{-# LANGUAGE OverloadedStrings #-}

module Estuary.Widgets.Config where

import Reflex hiding (Request,Response)
import Reflex.Dom hiding (Request,Response)
import qualified Data.Text as T
import Data.Map.Strict

import Estuary.Widgets.Editor
import Estuary.Widgets.Generic
import Estuary.Widgets.ViewEditor
import Estuary.Types.Context
import Estuary.Types.Language
import Estuary.Render.DynamicsMode
import qualified Estuary.Types.Term as Term
import Estuary.Types.RenderInfo

import qualified Sound.Punctual.Resolution as Punctual

configWidget :: MonadWidget t m => Dynamic t Context -> Dynamic t RenderInfo -> Editor t m (Event t ContextChange)
configWidget ctx ri = do

  canvasEnabledEv <- divClass "config-option primary-color ui-font" $ do
    text "Canvas: "
    canvasInput <- elClass "label" "switch" $ do
      x <- checkbox True def
      elClass "span" "slider round" (return x)
    el "div" $ dynText =<< (translatableText $ fromList [
      (English,"Enable the canvas to display visual results.")
      ])
    return $ fmap (\x -> \c -> c { canvasOn = x }) $ _checkbox_change canvasInput

  elClass "hr" "dashed" $ return ()

  resolutionChangeEv <- divClass "config-option primary-color ui-font" $ do
    term Term.Resolution >>= dynText
    text ": "
    let resolutions = [Punctual.QHD,Punctual.FHD,Punctual.HD,Punctual.WSVGA,Punctual.SVGA,Punctual.VGA,Punctual.QVGA]
    let resMap = fromList $ zip resolutions $ fmap (T.pack . show) resolutions
    resChange <- _dropdown_change <$> dropdown Punctual.HD (constDyn resMap) (def & attributes .~ constDyn ("class" =: "ui-dropdownMenus primary-color primary-borders ui-font"))
    el "div" $ dynText =<< (translatableText $ fromList [
      (English,"The resolution used for rendering visuals to the canvas. Values higher on the list require a more powerful graphics processing unit (GPU) and may result in a lower frames per second (FPS).")
      ])
    return $ fmap (\x c -> c { resolution = x }) resChange

  elClass "hr" "dashed" $ return ()

  fpsLimitChangeEv <- divClass "config-option primary-color ui-font" $ do
    text "FPS:"
    let fpsMap = fromList [(Just 0.030,"30"),(Just 0.060,"15"),(Just 0.015,"60"),(Nothing,"unlimited")]
    fpsChange <- _dropdown_change <$> dropdown (Just 0.030) (constDyn fpsMap) (def & attributes .~ constDyn ("class" =: "ui-dropdownMenus primary-color primary-borders ui-font"))
    el "div" $ dynText =<< (translatableText $ fromList [
      (English,"By default, visuals are limited to rendering at ~30 FPS. It is possible to set other limits and to have no limits on frame rate. Higher frame rates and unlimited frame rates may increase demands on the computer's CPU and GPU.")
      ])
    return $ fmap (\x c -> c { fpsLimit = x }) fpsChange

  elClass "hr" "dashed" $ return ()

  brightnessChangeEv <- divClass "config-option primary-color ui-font" $ do
    term Term.Brightness >>= dynText
    text ": "
    let brightnessMap = fromList [(1.0,"100%"),(0.5,"50%"),(0.25,"25%"),(0.1,"10%")]
    brightnessChange <- _dropdown_change <$> dropdown 1.0 (constDyn brightnessMap) (def & attributes .~ constDyn ("class" =: "ui-dropdownMenus primary-color primary-borders ui-font"))
    el "div" $ dynText =<< (translatableText $ fromList [
      (English,"The brightness of all rendered visuals. Can be used to make it easier to see code against bright, generated visuals.")
      ])
    return $ fmap (\x c -> c { brightness = x }) brightnessChange

  elClass "hr" "dashed" $  text ""

  webDirtEnabledEv <- divClass "config-option primary-color ui-font" $ do
    text "WebDirt: "
    wdInput <-elClass "label" "switch" $ do
      x <- checkbox True def
      elClass "span" "slider round" (return x)
    el "div" $ dynText =<< (translatableText $ fromList [
      (English,"WebDirt is the default, built-in rendering engine for sample events in Estuary. It uses the Web Audio API to play samples and thus requires no additional software to be installed.")
      ])
    return $ fmap (\x -> (\c -> c { webDirtOn = x } )) $ _checkbox_change wdInput

  elClass "hr" "dashed" $  text ""

  dynamicsModeEv <- divClass "config-option primary-color ui-font" $ do
    text "Dynamics: "
    let dmMap = fromList $ zip dynamicsModes (fmap (T.pack . show) dynamicsModes)
    dmChange <- _dropdown_change <$> dropdown DefaultDynamics (constDyn dmMap) (def & attributes .~ constDyn ("class" =: "ui-dropdownMenus primary-color primary-borders ui-font" <> "style" =: "background-color: transparent"))
    el "div" $ dynText =<< (translatableText $ fromList [
      (English,"Control of a global compressor that affects all audio produced within the browser by Estuary. The Loud preset is intended for noisy environments, and the Wide preset is intended for situations where many streams of audio are being combined and sent to further processing (eg. compression and gain) outside of the browser.")
      ])
    return $ fmap (\x c -> c { dynamicsMode = x }) dmChange -- context -> context

  elClass "hr" "dashed" $  text ""

  punctualAudioInputModeEv <- divClass "config-option primary-color ui-font" $ do
    text "Punctual Audio Input: "
    let paimMap = fromList $ zip punctualAudioInputModes (fmap (T.pack . show) punctualAudioInputModes)
    paimChange <- _dropdown_change <$> dropdown MicToPunctual (constDyn paimMap) (def & attributes .~ constDyn ("class" =: "ui-dropdownMenus primary-color primary-borders ui-font" <> "style" =: "background-color: transparent"))
    el "div" $ dynText =<< (translatableText $ fromList [
      (English,"Control of how microphone/WebDirt audio is routed to Punctual.")
      ])
    return $ fmap (\x c -> c { punctualAudioInputMode = x }) paimChange -- context -> context

  elClass "hr" "dashed" $  text ""

  superDirtEnabledEv <- divClass "config-option primary-color ui-font" $ do
    text "SuperDirt: "
    sdInput <- elClass "label" "switch" $ do
      x <- checkbox False def
      elClass "span" "slider round" (return x)
    el "div" $ dynText =<< (translatableText $ fromList [
      (English,"When enabled, sample events are sent out of the browser to be processed by other software. Requires the installation and use of additional software (eg. SuperDirt and the \"superDirtSocket\").")
      ])
    return $ fmap (\x -> (\c -> c { superDirtOn = x } )) $ _checkbox_change sdInput

  elClass "hr" "dashed" $  text ""

  unsafeModeEv <- divClass "config-option primary-color ui-font" $ do
    text "Unsafe Mode:"
    unsafeInput <- elClass "label" "switch" $ do
      x <- checkbox False def
      elClass "span" "slider round" (return x)
    el "div" $ dynText =<< (translatableText $ fromList [
      (English,"Activating unsafe mode may make additional functionality available at the risk of catastrophic performance problems. Use at own risk.")
      ])
    return $ fmap (\x -> \c -> c { unsafeMode = x }) $ _checkbox_change unsafeInput

  elClass "hr" "dashed" $ return ()

  viewEditorChange <- divClass "config-option primary-color ui-font" $ do
    el "h3" $ text "View Editor"
    viewEditor

  return $ mergeWith (.) [punctualAudioInputModeEv,canvasEnabledEv, superDirtEnabledEv, webDirtEnabledEv, dynamicsModeEv, resolutionChangeEv, brightnessChangeEv, viewEditorChange, fpsLimitChangeEv, unsafeModeEv]

{-# LANGUAGE ScopedTypeVariables, OverloadedStrings, RecursiveDo #-}

module Estuary.Widgets.Text where

import Reflex
import Reflex.Dom hiding (getKeyEvent,preventDefault)
import Reflex.Dom.Contrib.KeyEvent
import Control.Monad
import Control.Monad.Trans
import GHCJS.DOM.EventM
import Data.Maybe
import Data.Map
import Data.Monoid
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time

import Estuary.Tidal.Types
import Estuary.Reflex.Container
import Estuary.Widgets.GeneralPattern
import Estuary.Reflex.Utility
import Estuary.Widgets.Generic
import Estuary.Utility (lastOrNothing)
import Estuary.Types.Definition
import Estuary.Types.Hint
import Estuary.Types.TidalParser
import Estuary.Languages.TidalParsers
import Estuary.Types.Live
import Estuary.Types.TextNotation
import Estuary.Help.LanguageHelp
import Estuary.Reflex.Utility
import qualified Estuary.Types.Term as Term
import Estuary.Types.Language
import Estuary.Widgets.Editor
import Estuary.Types.Context
import Estuary.Types.Variable

textWidgetClass :: Bool -> Map Text Text
textWidgetClass True = "class" =: "evalFlash textInputToEndOfLine code-font"
textWidgetClass False = "class" =: "primary-color textInputToEndOfLine code-font"

textWidgetRows :: Int -> Map Text Text
textWidgetRows 0 = Data.Map.empty
textWidgetRows x = "rows" =: T.pack (show x)

textWidget :: MonadWidget t m => Int -> Dynamic t Bool -> Text -> Event t Text -> m (Dynamic t Text, Event t Text, Event t ())
textWidget rows flash i delta = do
  let class' = fmap textWidgetClass flash
  let rows' = constDyn $ textWidgetRows rows
  let style = constDyn $ "style" =: "height: auto"
  let attrs = mconcat [class',rows',style]
  x <- textArea $ def & textAreaConfig_setValue .~ delta & textAreaConfig_attributes .~ attrs & textAreaConfig_initialValue .~ i
  let e = _textArea_element x
  e' <- wrapDomEvent (e) (onEventName Keypress) $ do
    y <- getKeyEvent
    if keyPressWasShiftEnter y then (preventDefault >> return True) else return False
  let evalEvent = fmap (const ()) $ ffilter (==True) e'
  let edits = _textArea_input x
  let value = _textArea_value x
  return (value,edits,evalEvent)
  where keyPressWasShiftEnter ke = (keShift ke == True) && (keKeyCode ke == 13)


textNotationParsers :: [TextNotation]
textNotationParsers = [Punctual, CineCer0, TimeNot, Seis8s, Hydra {--Ver, Oir--}] ++ (fmap TidalTextNotation tidalParsers)


textProgramEditor :: forall t m. MonadWidget t m => Int -> Dynamic t (Maybe Text)
  -> Dynamic t (Live TextProgram) -> Editor t m (Variable t (Live TextProgram))
textProgramEditor rows errorText deltasDown = divClass "textPatternChain" $ mdo -- *** TODO: change css class

  -- determine whether we currently display "eval flash" or not
  evalTimeDyn <- holdUniqDyn $ fmap ((\(_,_,x)->x) . forRendering) $ currentValue cv
  let flashOn = traceEvent "flashOn" $ fmap (const True) $ updated evalTimeDyn -- Event t Bool, fires every time evalTime changes
  flashOff <- liftM (traceEvent "flashOff" . fmap (const False)) $ delay 0.1 flashOn -- Event t Bool, fires 0.1 seconds later
  evalFlash <- holdDyn False $ leftmost [flashOff,flashOn] -- Dynamic t Bool

  --
  i <- sample $ current deltasDown
  let delta = updated deltasDown
  let deltaFuture = fmap forEditing delta
  let parserFuture = fmap (\(x,_,_) -> x) deltaFuture
  let textFuture = fmap (\(_,x,_) -> x) deltaFuture
  let initialParser = (\(x,_,_) -> x) $ forEditing i
  let parserMap = constDyn $ fromList $ fmap (\x -> (x,T.pack $ textNotationDropDownLabel x)) textNotationParsers

  (d,evalButton) <- divClass "fullWidthDiv" $ do
    d' <- dropdown initialParser parserMap $ ((def :: DropdownConfig t TidalParser) & attributes .~ constDyn ("class" =: "ui-dropdownMenus code-font primary-color primary-borders")) & dropdownConfig_setValue .~ parserFuture
    evalButton' <- divClass "textInputLabel" $ do
      x <- dynButton "\x25B6"
      return x
    e' <- holdUniqDyn errorText
    let y = fmap (maybe (return ()) syntaxErrorWidget) $ updated e'
    widgetHold (return ()) y
    return (d',evalButton')

  (edit,eval) <- divClass "labelAndTextPattern" $ do
    let parserValue = _dropdown_value d -- Dynamic t TidalParser
    let parserEvent = _dropdown_change d
    let initialText = (\(_,x,_) -> x) $ forEditing i
    (textValue,textEvent,shiftEnter) <- textWidget rows evalFlash initialText textFuture
    languageToDisplayHelp <- (holdDyn initialParser $ updated parserValue) >>= holdUniqDyn

    let evalEvent = leftmost [evalButton,shiftEnter]
    let initialEvalTime = (\(_,_,x) -> x) $ forRendering i
    localEvalTime <- performEvent $ fmap (liftIO . const getCurrentTime) evalEvent
    let remoteEvalTime = fmap ( (\(_,_,x) -> x) . forRendering) delta
    evalTimeValue <- holdDyn initialEvalTime $ leftmost [localEvalTime,remoteEvalTime]

    let v' = (\x y z -> (x,y,z)) <$> parserValue <*> textValue <*> evalTimeValue
    let editEvent = tagPromptlyDyn v' $ leftmost [() <$ parserEvent,() <$ textEvent]
    let evalEvent' = attachPromptlyDynWith (\(x,y,_) z -> (x,y,z)) v' localEvalTime
    return (editEvent,evalEvent')
  let deltaPast = fmap forRendering delta
  pastValue <- holdDyn (forRendering i) $ leftmost [deltaPast,eval]
  futureValue <- holdDyn (forEditing i) $ leftmost [deltaFuture,edit]
  let value = f <$> pastValue <*> futureValue
  let deltaUpEdit = tagPromptlyDyn value edit
  let deltaUpEval = tagPromptlyDyn value eval
  let deltaUp = leftmost [deltaUpEdit,deltaUpEval]
  cv <- returnVariable deltasDown deltaUp
  return cv
  where
    f p x | p == x = Live p L3 -- *** TODO: this looks like it is a general pattern that should be with Live definitions
          | otherwise = Edited p x


labelEditor :: MonadWidget t m => Dynamic t Text -> Editor t m (Variable t Text)
labelEditor delta = do
  let attrs = constDyn $ ("class" =: "name-tag-textarea code-font primary-color")
  y <- divClass "labelWidgetDiv" $ do
    i <- sample $ current delta
    textInput $ def & textInputConfig_setValue .~ (updated delta) & textInputConfig_attributes .~ attrs & textInputConfig_initialValue .~ i
  returnVariable delta $ _textInput_input y

syntaxErrorWidget :: MonadWidget t m => Text -> Editor t m ()
syntaxErrorWidget t = do
  s <- term Term.Syntax
  let wb = elClass "div" "syntaxIssue" $ dynText s
  tooltip wb (text t)
  return ()

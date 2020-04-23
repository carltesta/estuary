{-# LANGUAGE OverloadedStrings #-}

module Estuary.Widgets.Footer where

import Reflex
import Reflex.Dom
import Data.Text (Text)
import qualified Data.Text as T
import TextShow
import Control.Monad

import Estuary.Types.Context
import Estuary.Types.RenderInfo
import qualified Estuary.Types.Term as Term
import Estuary.Types.Hint
import Estuary.Widgets.Editor
import Estuary.Widgets.Generic
import Estuary.Reflex.Utility (dynButton)

footer :: MonadWidget t m => Event t [Hint] -> Editor t m (Event t ())
footer hints = divClass "footer" $ do
  terminalButton <- el "div" $ dynButton ">_"
  let statsEvent = ffilter (elem ToggleStats) hints
  statsVisible <- toggle True statsEvent
  hideableWidget' statsVisible $ do
    divClass "peak primary-color code-font" $ do
      ctx <- context
      ri <- renderInfo
      cc <- fmap (fmap showt) $ holdUniqDyn $ fmap clientCount ctx
      dynText cc
      text " "
      term Term.Connections >>= dynText
      text ", "
      term Term.Latency >>= dynText
      text " "
      sl <- fmap (fmap $ (showt :: Int -> Text) . round . (*1000)) $ holdUniqDyn $ fmap serverLatency ctx
      dynText sl
      text "ms, "
      term Term.Load >>= dynText
      text " "
      (fmap (fmap showt) $ holdUniqDyn $ fmap avgRenderLoad ri) >>= dynText
      text "%,   "
      (fmap (fmap showt) $ holdUniqDyn $ fmap animationFPS ri) >>= dynText
      text "FPS ("
      (fmap (fmap (showt :: Int -> Text)) $ holdUniqDyn $ fmap animationLoad ri) >>= dynText
      text "ms)"
  return terminalButton

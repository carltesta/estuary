{-# LANGUAGE RecursiveDo, JavaScriptFFI, OverloadedStrings #-}

module Estuary.Widgets.CanvasDisplay (canvasDisplay) where

import Reflex
import Reflex.Dom
import GHCJS.DOM.Types (JSVal,HTMLCanvasElement)
import qualified GHCJS.DOM.Types as G
import GHCJS.Foreign.Callback
import Data.JSString as J
import Data.Map
import Data.Text as T
import Data.List
import Control.Monad
import Control.Monad.Trans
import Control.Concurrent.MVar
import Data.Time.Clock
import JavaScript.Web.AnimationFrame
import GHCJS.Concurrent

import Estuary.Types.Color
import Estuary.Types.CanvasOp
import Estuary.Types.CanvasState
import Estuary.RenderInfo

canvasDisplay :: MonadWidget t m => Int -> MVar CanvasState -> m ()
canvasDisplay z mv = do
  let attrs = fromList [("class","canvasDisplay"),("style",T.pack $ "z-index:" ++ show z),("width","1920"),("height","1080")]
  cvs <- liftM (G.uncheckedCastTo G.HTMLCanvasElement .  _element_raw . fst) $ elAttr' "canvas" attrs $ return ()
  ctx <- liftIO $ getContext cvs
  liftIO $ requestAnimationFrame ctx mv
  -- *** note: also need to consider how to interrupt requestAnimationFrame when widget is destroyed

requestAnimationFrame :: JSVal -> MVar CanvasState -> IO ()
requestAnimationFrame ctx mv = do
  inAnimationFrame ThrowWouldBlock $ redrawCanvas ctx mv
  return ()

redrawCanvas :: JSVal -> MVar CanvasState -> Double -> IO ()
redrawCanvas ctx mv _ = synchronously $ do
  t1 <- getCurrentTime
  cState <- takeMVar mv
  let ops = queuedOps cState
  let n1 = Prelude.length ops
  ops' <- flushCanvasOps ctx ops
  let n2 = Prelude.length ops'
  putMVar mv $ cState { queuedOps = ops', previousDrawStart = t1 }
  t3 <- getCurrentTime
  let interFrameDelay = diffUTCTime t1 (previousDrawStart cState)
  let drawDelay = diffUTCTime t3 t1
  let opsDrawn = n1 - n2
  -- putStrLn $ show drawDelay ++ "s for " ++ show opsDrawn ++ " ops"
  -- putStrLn $ "interFrameDelay = " ++ show interFrameDelay ++ "; drawDelay = " ++ show drawDelay ++ " (" ++ show opsDrawn ++ " ops drawn)"
  requestAnimationFrame ctx mv

flushCanvasOps :: JSVal -> [(UTCTime,CanvasOp)] -> IO [(UTCTime,CanvasOp)]
flushCanvasOps ctx ops = do
  now <- getCurrentTime
  let (opsForNow,opsForLater) = Data.List.partition ((<= now) . fst) ops
  performCanvasOps ctx opsForNow
  return opsForLater

performCanvasOps :: JSVal -> [(UTCTime,CanvasOp)] -> IO ()
performCanvasOps ctx ops = mapM_ (canvasOp ctx) $ fmap (toActualWandH 1920 1080 . snd) ops

canvasOp :: JSVal -> CanvasOp -> IO ()
canvasOp ctx (Clear a) = do
  fillStyle ctx (J.pack $ show $ RGBA 0 0 0 a)
  strokeStyle ctx (J.pack $ show $ RGBA 0 0 0 a)
  rect ctx 0 0 1920 1080
  stroke ctx
  fill ctx
canvasOp ctx (Rect x y w h) = beginPath ctx >> rect ctx x y w h >> stroke ctx >> fill ctx
canvasOp ctx (Tri x0 y0 x1 y1 x2 y2) = do
  beginPath ctx
  moveTo ctx x0 y0
  lineTo ctx x1 y1
  lineTo ctx x2 y2
  lineTo ctx x0 y0
  stroke ctx
  fill ctx
canvasOp ctx (MoveTo x y) = moveTo ctx x y
canvasOp ctx (LineTo x y) = beginPath ctx >> lineTo ctx x y >> stroke ctx >> fill ctx
canvasOp ctx (StrokeStyle c) = strokeStyle ctx (J.pack $ show c)
canvasOp ctx (FillStyle c) = fillStyle ctx (J.pack $ show c)

foreign import javascript safe
  "$r=$1.getContext('2d')"
  getContext :: HTMLCanvasElement -> IO JSVal

foreign import javascript unsafe
  "$1.beginPath()"
  beginPath :: JSVal -> IO ()

foreign import javascript unsafe
  "$1.stroke()"
  stroke :: JSVal -> IO ()

foreign import javascript unsafe
  "$1.fill()"
  fill :: JSVal -> IO ()

foreign import javascript unsafe
  "$1.strokeStyle = $2"
  strokeStyle :: JSVal -> JSString -> IO ()

foreign import javascript unsafe
  "$1.fillStyle = $2"
  fillStyle :: JSVal -> JSString -> IO ()

foreign import javascript unsafe
  "$1.rect($2,$3,$4,$5)"
  rect :: JSVal -> Double -> Double -> Double -> Double -> IO ()

foreign import javascript unsafe
  "$1.moveTo($2,$3)"
  moveTo :: JSVal -> Double -> Double -> IO ()

foreign import javascript unsafe
  "$1.lineTo($2,$3)"
  lineTo :: JSVal -> Double -> Double -> IO ()

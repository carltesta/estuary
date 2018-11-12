{-# LANGUAGE RecursiveDo, ScopedTypeVariables #-}

module Estuary.Reflex.Router where

import Control.Monad.IO.Class

import Data.Maybe

import GHCJS.DOM.EventM(on, event)
import GHCJS.DOM.Types(ToJSString(..), FromJSString(..))

import GHCJS.DOM(currentWindow,)
import GHCJS.DOM.History
import qualified GHCJS.DOM.PopStateEvent as PopStateEvent
import qualified GHCJS.DOM.Window as Window(getHistory, popState)

import GHCJS.Marshal
import GHCJS.Marshal.Pure
import GHCJS.Nullable

import Reflex
import Reflex.Dom

-- currentWindow :: IO (Maybe Window)
-- getHistory :: Window -> IO (Maybe History)
-- pushState :: (MonadIO m, ToJSString title, ToJSString url) =>
--     History -> JSVal -> title -> url -> m ()

router :: (MonadWidget t m, FromJSVal state, ToJSVal state) => state -> (state -> m (Event t state)) -> m ()
router def renderPage = mdo
  state <- liftIO $ getInitialState def

  let initialPage = renderPage state

  -- Triggered ambiently (back button or otherwise). If the state is null or can't
  -- be decoded, fall back into the initial state.
  popStateEv :: Event t state <- fmap (fromMaybe def) <$> getPopStateEv

  -- Triggered via a page widget (stateChangeEvEv is returned from the dyn below).
  -- Needs to be flattened because dyn actually returns an event of the returned event.
  -- When a change is explicitly triggered, we notify the history via pushPageState.
  triggeredStateChangeEv :: Event t state <- switchPromptly never stateChangeEvEv
  performEvent_ $ ffor triggeredStateChangeEv $ \state -> liftIO $ do
    pushPageState state "?test"

  -- The router state is changed when either the browser buttons are pressed or
  -- a child page triggers a change.
  let stateChangeEv = leftmost [popStateEv, triggeredStateChangeEv]

  dynPage :: Dynamic t (m (Event t state)) <- holdDyn initialPage (renderPage <$> stateChangeEv)
  
  -- Dynamic t (Event t State)
  stateChangeEvEv :: Event t (Event t state) <- dyn dynPage

  return ()

getInitialState :: (FromJSVal state) => state -> IO (state)
getInitialState def = 
  maybeIO def currentWindow $ \window ->
    maybeIO def (Window.getHistory window) $ \history -> do
      maybeIO def (pFromJSVal <$> pToJSVal <$> getState history) $ \state ->
        maybeIO def (liftIO $ fromJSVal state) return

pushPageState :: (ToJSVal state, ToJSString url) => state -> url -> IO ()
pushPageState state url = do
  maybeIO () currentWindow $ \window ->
    maybeIO () (Window.getHistory window) $ \history -> do
      jsState <- liftIO $ toJSVal state
      -- Mozilla reccomends to pass "" as title to keep things future proof
      pushState history jsState "" url

getPopStateEv :: (MonadWidget t m, FromJSVal state) => m (Event t (Maybe state))
getPopStateEv = do
  mWindow <- liftIO $ currentWindow
  case mWindow of
    Nothing -> return never
    Just window -> 
      wrapDomEvent window (\e -> on e Window.popState) $ do
        -- in (EventM t PopState) which is (ReaderT PopState IO)
        eventData <- event -- ask
        nullableJsState <- liftIO $ pFromJSVal <$> pToJSVal <$> PopStateEvent.getState eventData
        case nullableJsState of
          Nothing -> return Nothing
          Just jsState -> liftIO $ fromJSVal jsState


maybeIO :: b -> IO (Maybe a) -> (a -> IO b) -> IO b
maybeIO def computeA computeBFromA = do
  val <- computeA
  case val of
    Nothing -> return def
    Just a -> computeBFromA a
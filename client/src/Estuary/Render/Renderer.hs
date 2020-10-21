{-# LANGUAGE OverloadedStrings, ScopedTypeVariables #-}

module Estuary.Render.Renderer where

import Data.Time.Clock
import Data.Time.Clock.POSIX
import qualified Sound.Tidal.Context as Tidal
import Control.Monad.IO.Class (liftIO)
import Control.Monad.State.Strict
import Control.Concurrent
import Control.Concurrent.MVar
import Control.Exception (evaluate,catch,SomeException,try)
import Control.DeepSeq
import Control.Monad.Loops
import Data.Functor (void)
import Data.List (intercalate,zipWith4)
import Data.IntMap.Strict as IntMap
import Data.Maybe
import Data.Either
import qualified Data.Map.Strict as Map
import JavaScript.Web.AnimationFrame
import GHCJS.Concurrent
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as T
import Data.Bifunctor
import TextShow
import Sound.OSC.Datum
import Text.Parsec (ParseError)
import qualified Data.ByteString as B
import GHCJS.DOM.Types (HTMLCanvasElement)
import Data.Witherable

import Sound.MusicW.AudioContext
import qualified Sound.Punctual.Program as Punctual
import qualified Sound.Punctual.PunctualW as Punctual
import qualified Sound.Punctual.GL as Punctual
import qualified Sound.Punctual.WebGL as Punctual
import qualified Sound.Punctual.AsyncProgram as Punctual
import qualified Sound.Punctual.Parser as Punctual
import qualified Sound.Punctual.Resolution as Punctual
import qualified Sound.TimeNot.AST as TimeNot
import qualified Sound.TimeNot.Parsers as TimeNot
import qualified Sound.TimeNot.Render as TimeNot
import qualified Sound.Seis8s.Parser as Seis8s

import Estuary.Types.Definition
import Estuary.Types.TextNotation
import Estuary.Tidal.Types
import Estuary.Tidal.ParamPatternable
import Estuary.Types.Live
import qualified Estuary.Render.WebDirt as WebDirt
import qualified Estuary.Render.SuperDirt as SuperDirt
import Estuary.Types.NoteEvent
import Estuary.Types.RenderInfo
import Estuary.Types.RenderState
import Estuary.Types.Tempo
import Estuary.Types.MovingAverage
import Estuary.Render.DynamicsMode

import qualified Estuary.Languages.Hydra.Types as Hydra
import qualified Estuary.Languages.Hydra.Parser as Hydra
import qualified Estuary.Languages.Hydra.Render as Hydra
import qualified Estuary.Languages.CineCer0.CineCer0State as CineCer0
import qualified Estuary.Languages.CineCer0.Spec as CineCer0
import qualified Estuary.Languages.CineCer0.Parser as CineCer0
import Estuary.Languages.TidalParsers
import Estuary.Languages.TextReplacement


type Renderer = StateT RenderState IO ()

clockRatioThreshold :: Double
clockRatioThreshold = 0.8

maxRenderLatency :: NominalDiffTime
maxRenderLatency = 0.360

maxRenderPeriod :: NominalDiffTime
maxRenderPeriod = 0.360

minRenderLatency :: NominalDiffTime
minRenderLatency = 0.070

minRenderPeriod :: NominalDiffTime
minRenderPeriod = 0.120

-- should be somewhat larger than maxRenderLatency
waitThreshold :: NominalDiffTime
waitThreshold = 0.380

rewindThreshold :: NominalDiffTime
rewindThreshold = 1.0

earlyWakeUp :: NominalDiffTime
earlyWakeUp = 0.002

processEnsembleEvents :: Renderer
processEnsembleEvents = do
  eevsM <- ensembleEventsM <$> get
  eevs <- takeMVar eevsM
  putMVar eevsM []
  mapM_ processEnsembleEvent eevs

processEnsembleEvent :: EnsembleEvent -> Renderer
processEnsembleEvent (TempoEvent t) = modify' $ \s -> s { tempo = t }
processEnsembleEvent (ZoneEvent n d) = do
  -- there are several scenarios to account for when we receive a ZoneEvent:
  -- (1) new definition where there wasn't one previously (parse)
  -- (2) new definition of same type/language (parse again)
  -- (3) changed definition of new type/language (clear state/nodes/etc before parsing again)
  cache <- cachedDefs <$> get
  let prevDef = IntMap.lookup n cache -- Maybe Definition
  let needToClear = case prevDef of
    Just prevDef' ->
      -- *** TODO ***
    Nothing ->
  when needToClear $ do -- clear state/nodes/etc if was previously a definition with a different notation
    -- *** TODO
  -- parse/process the new definition as necessary


  -- *** WORKING HERE ***

processEnsembleEvent ClearZones = clearZones
processEnsembleEvent (JoinEvent _ _ _ _) = clearZones
processEnsembleEvent LeaveEvent = clearZones
processEnsembleEvent _ = return ()

clearZones :: Renderer
clearZones = do
  -- *** WORKING HERE ***

InsertAudioResource Text Text Int | -- "url" [bankName] [n]
DeleteAudioResource Text Int | -- [bankName] [n]
AppendAudioResource Text Text | -- "url" [bankName]
deriving (Eq,Generic)




pushNoteEvents :: [NoteEvent] -> Renderer
pushNoteEvents xs = modify' $ \x -> x { noteEvents = noteEvents x ++ xs }

pushTidalEvents :: [(UTCTime,Tidal.ControlMap)] -> Renderer
pushTidalEvents xs = modify' $ \x -> x { tidalEvents = tidalEvents x ++ xs }

-- flush events for SuperDirt and WebDirt
flushEvents :: ImmutableRenderContext -> Context -> Renderer
flushEvents irc c = do
  s <- get
  when (webDirtOn c) $ liftIO $ do
    let cDiff = (wakeTimeSystem s,wakeTimeAudio s)
    noteEvents' <- witherM (WebDirt.noteEventToWebDirtJSVal (audioMap c) cDiff) $ noteEvents s
    tidalEvents' <- witherM (WebDirt.tidalEventToWebDirtJSVal (audioMap c) cDiff) $ tidalEvents s
    mapM_ (WebDirt.playSample (webDirt irc)) $ noteEvents' ++ tidalEvents'
  when (superDirtOn c) $ liftIO $ do
    noteEvents' <- mapM (SuperDirt.noteEventToSuperDirtJSVal (audioMap c)) $ noteEvents s
    tidalEvents' <- mapM (SuperDirt.tidalEventToSuperDirtJSVal (audioMap c)) $ tidalEvents s
    mapM_ (SuperDirt.playSample (superDirt irc)) $ noteEvents' ++ tidalEvents'
  modify' $ \x -> x { noteEvents = [], tidalEvents = [] }
  return ()

renderTidalPattern :: UTCTime -> NominalDiffTime -> Tempo -> Tidal.ControlPattern -> [(UTCTime,Tidal.ControlMap)]
renderTidalPattern start range t p = events''
  where
    start' = (realToFrac $ diffUTCTime start (time t)) * freq t + count t -- start time in cycles since beginning of tempo
    end = realToFrac range * freq t + start' -- end time in cycles since beginning of tempo
    events = Tidal.queryArc p (Tidal.Arc (toRational start') (toRational end)) -- events with t in cycles
    events' = Prelude.filter Tidal.eventHasOnset events
    events'' = f <$> events'
    f e = (utcTime,Tidal.value e)
      where
        utcTime = addUTCTime (realToFrac ((fromRational w1 - count t)/freq t)) (time t)
        w1 = Tidal.start $ fromJust $ Tidal.whole e

sequenceToControlPattern :: (Text,[Bool]) -> Tidal.ControlPattern
sequenceToControlPattern (sampleName,pat) = Tidal.s $ parseBP' $ intercalate " " $ fmap f pat
  where f False = "~"
        f True = T.unpack sampleName

render :: ImmutableRenderContext -> Context -> Renderer
render irc c = do
  s <- get
  -- check if audio clock has advanced same amount as system clock
  t1System <- liftIO $ getCurrentTime
  t1Audio <- liftAudioIO $ audioTime
  let elapsedSystem = (realToFrac $ diffUTCTime t1System $ wakeTimeSystem s) :: Double
  let elapsedAudio = t1Audio - wakeTimeAudio s
  let cr = elapsedAudio / elapsedSystem
  let crProblem = cr < clockRatioThreshold && cr > 0
  modify' $ \x -> x {
    wakeTimeSystem = t1System,
    wakeTimeAudio = t1Audio,
    info = (info x) { clockRatio = cr, clockRatioProblem = crProblem }
  }
  when crProblem $ liftIO $ T.putStrLn $ "audio clock slower, ratio=" <> showt cr

  -- four possible timing scenarios to account for...
  let diff = diffUTCTime (renderEnd s) t1System
  -- 1. Fast Forward
  when (diff < minRenderLatency) $ do
    liftIO $ T.putStrLn "FAST-FORWARD"
    modify' $ \x -> x {
      renderStart = addUTCTime minRenderLatency t1System,
      renderPeriod = minRenderPeriod,
      renderEnd = addUTCTime (minRenderPeriod+minRenderLatency) t1System
    }

  -- 2. Normal Advance
  when (diff >= minRenderLatency && diff <= waitThreshold) $ do
    let ratio0 = (diff - minRenderLatency) / (maxRenderLatency - minRenderLatency)
    let ratio = min 1 ratio0
    let adaptivePeriod = ratio * (maxRenderPeriod - minRenderPeriod) + minRenderPeriod
    -- liftIO $ T.putStrLn $ "NORMAL " <> showt (realToFrac ratio :: Double) <> " " <> showt (realToFrac adaptivePeriod :: Double)
    modify' $ \x -> x {
      renderStart = renderEnd s,
      renderPeriod = adaptivePeriod,
      renderEnd = addUTCTime adaptivePeriod (renderEnd s)
    }

  -- 3. Wait
  let wait = (diff > waitThreshold && diff < rewindThreshold)
  when wait $ liftIO $ T.putStrLn $ "WAIT " <> showt (realToFrac diff :: Double)

  -- 4. Rewind
  let rewind = (diff >= rewindThreshold)
  when rewind $ do
    liftIO $ T.putStrLn $ "REWIND"
    modify' $ \x -> x {
      renderStart = addUTCTime minRenderLatency t1System,
      renderPeriod = minRenderPeriod,
      renderEnd = addUTCTime (minRenderPeriod+minRenderLatency) t1System
    }

  -- if there is no reason not to traverse/render zones, then do so
  -- using renderStart and renderEnd from the state as the window to render
  when (not wait && not rewind) $ do
    traverseWithKey (renderZone irc c) (zones $ ensemble $ ensembleC c)
    flushEvents irc c
    updatePunctualResolutionAndBrightness c
    -- calculate how much time this render cycle took and update load measurements
    t2System <- liftIO $ getCurrentTime
    t2Audio <- liftAudioIO $ audioTime
    let mostRecentRenderTime = diffUTCTime t2System t1System
    let newRenderTime = updateAverage (renderTime s) $ realToFrac mostRecentRenderTime
    let newAvgRenderLoad = ceiling (getAverage newRenderTime * 100 / realToFrac maxRenderPeriod)
    modify' $ \x -> x { renderTime = newRenderTime }
    modify' $ \x -> x { info = (info x) { avgRenderLoad = newAvgRenderLoad }}
    traverseWithKey calculateZoneRenderTimes $ zoneRenderTimes s -- *** SHOULDN'T BE HERE
    traverseWithKey calculateZoneAnimationTimes $ zoneAnimationTimes s -- *** SHOULDN'T BE HERE
    return ()
  -- sleepIfNecessary

setZoneError :: Int -> Text -> Renderer
setZoneError z t = do
  s <- get
  let oldErrors = errors $ info s
  let newErrors = insert z t oldErrors
  modify' $ \x -> x { info = (info s) { errors = newErrors } }

clearZoneError :: Int -> Renderer
clearZoneError z = do
  s <- get
  let oldErrors = errors $ info s
  let newErrors = delete z oldErrors
  modify' $ \x -> x { info = (info s) { errors = newErrors } }

renderZone :: ImmutableRenderContext -> Context -> Int -> Definition -> Renderer
renderZone irc c z d = do
  t1 <- liftIO $ getCurrentTime
  s <- get
  let prevDef = IntMap.lookup z $ cachedDefs s
  let d' = definitionForRendering d
  when (prevDef /= (Just d')) $ do
    renderZoneChanged irc c z d'
    modify' $ \x -> x { cachedDefs = insert z d' (cachedDefs s) }
  renderZoneAlways irc c z d'
  t2 <- liftIO $ getCurrentTime
  let prevZoneRenderTimes = findWithDefault (newAverage 20) z $ zoneRenderTimes s
  let newZoneRenderTimes = updateAverage prevZoneRenderTimes (realToFrac $ diffUTCTime t2 t1)
  modify' $ \x -> x { zoneRenderTimes = insert z newZoneRenderTimes (zoneRenderTimes s) }

renderAnimation :: Renderer
renderAnimation = do
  t1 <- liftIO $ getCurrentTime
  defs <- gets cachedDefs
  traverseWithKey (renderZoneAnimation t1) defs
  s <- get
  newWebGL <- liftIO $
    Punctual.displayPunctualWebGL (glContext s) (punctualWebGL s)
    `catch` (\e -> putStrLn (show (e :: SomeException)) >> return (punctualWebGL s))
  t2 <- liftIO $ getCurrentTime
  let newAnimationDelta = updateAverage (animationDelta s) (realToFrac $ diffUTCTime t1 (wakeTimeAnimation s))
  let newAnimationTime = updateAverage (animationTime s) (realToFrac $ diffUTCTime t2 t1)
  let newAnimationFPS = round $ 1 / getAverage newAnimationDelta
  let newAnimationLoad = round $ getAverage newAnimationTime * 1000
  modify' $ \x -> x {
    punctualWebGL = newWebGL,
    wakeTimeAnimation = t1,
    animationDelta = newAnimationDelta,
    animationTime = newAnimationTime,
    info = (info x) {
      animationFPS = newAnimationFPS,
      animationLoad = newAnimationLoad
      }
    }

renderZoneAnimation :: UTCTime -> Int -> Definition -> Renderer
renderZoneAnimation tNow z (TextProgram x) = do
  t1 <- liftIO $ getCurrentTime
  renderZoneAnimationTextProgram tNow z $ forRendering x
  t2 <- liftIO $ getCurrentTime
  s <- get
  let prevZoneAnimationTimes = findWithDefault (newAverage 20) z $ zoneAnimationTimes s
  let newZoneAnimationTimes = updateAverage prevZoneAnimationTimes (realToFrac $ diffUTCTime t2 t1)
  modify' $ \x -> x { zoneAnimationTimes = insert z newZoneAnimationTimes (zoneAnimationTimes s) }
  return ()
renderZoneAnimation  _ _ _ = return ()

renderZoneAnimationTextProgram :: UTCTime -> Int -> TextProgram -> Renderer
renderZoneAnimationTextProgram tNow z (Punctual,x,eTime) = renderPunctualWebGL tNow z
renderZoneAnimationTextProgram tNow z (CineCer0,x,eTime) = renderCineCer0 tNow z
renderZoneAnimationTextProgram tNow z (Hydra,x,eTime) = renderHydra tNow z
renderZoneAnimationTextProgram  _ _ _ = return ()

updatePunctualResolutionAndBrightness :: Context -> Renderer
updatePunctualResolutionAndBrightness ctx = do
  s <- get
  newWebGL <- liftIO $
    do
      x <- Punctual.setResolution (glContext s) (resolution ctx) (punctualWebGL s)
      Punctual.setBrightness (brightness ctx) x
    `catch` (\e -> putStrLn (show (e :: SomeException)) >> return (punctualWebGL s))
  modify' $ \x -> x { punctualWebGL = newWebGL }

renderPunctualWebGL :: UTCTime -> Int -> Renderer
renderPunctualWebGL tNow z = do
  s <- get
  let tNow' = utcTimeToAudioSeconds (wakeTimeSystem s,wakeTimeAudio s) tNow
  newWebGL <- liftIO $
    Punctual.drawPunctualWebGL (glContext s) tNow' z (punctualWebGL s)
    `catch` (\e -> putStrLn (show (e :: SomeException)) >> return (punctualWebGL s))
  modify' $ \x -> x { punctualWebGL = newWebGL }

renderCineCer0 :: UTCTime -> Int -> Renderer
renderCineCer0 tNow z = do
  s <- get
  case videoDivCache s of
    Nothing -> return ()
    Just theDiv -> do
      let spec = IntMap.findWithDefault (CineCer0.emptySpec $ renderStart s) z (cineCer0Specs s)
      let prevState = IntMap.findWithDefault (CineCer0.emptyCineCer0State theDiv) z $ cineCer0States s
      newState <- liftIO $ CineCer0.updateCineCer0State (tempoCache s) tNow spec prevState
      modify' $ \x -> x { cineCer0States = insert z newState (cineCer0States s) }

renderHydra :: UTCTime -> Int -> Renderer
renderHydra tNow z = do
  s <- get
  let x = IntMap.lookup z $ hydras s
  case x of
    Just hydra -> liftIO $ Hydra.tick hydra 16.6667
    Nothing -> return ()

renderZoneChanged :: ImmutableRenderContext -> Context -> Int -> Definition -> Renderer
renderZoneChanged irc c z (TidalStructure x) = do
  let newParamPattern = toParamPattern x
  s <- get
  modify' $ \x -> x { paramPatterns = insert z newParamPattern (paramPatterns s) }
renderZoneChanged irc c z (TextProgram x) = do
  renderTextProgramChanged irc c z $ forRendering x
renderZoneChanged irc c z (Sequence xs) = do
  let newParamPattern = Tidal.stack $ Map.elems $ Map.map sequenceToControlPattern xs
  s <- get
  modify' $ \x -> x { paramPatterns = insert z newParamPattern (paramPatterns s) }
renderZoneChanged _ _ _ _ = return ()

renderZoneAlways :: ImmutableRenderContext -> Context -> Int -> Definition -> Renderer
renderZoneAlways irc c z (TidalStructure _) = renderControlPattern irc c z
renderZoneAlways irc c z (TextProgram x) = do
  let (_,_,evalTime) = forRendering x
  renderTextProgramAlways irc c z evalTime
renderZoneAlways irc c z (Sequence _) = renderControlPattern irc c z
renderZoneAlways _ _ _ _ = return ()

renderTextProgramChanged :: ImmutableRenderContext -> Context -> Int -> TextProgram -> Renderer
renderTextProgramChanged irc c z prog = do
  let x = applyTextReplacement prog
  renderBaseProgramChanged irc c z x
  case x of
    (Right x') -> do
      let (n,_,eTime) = x'
      s <- get
      let oldBaseNotations = baseNotations s
      let oldEvaluationTimes = evaluationTimes s
      modify' $ \y -> y { baseNotations = insert z n oldBaseNotations, evaluationTimes = insert z eTime oldEvaluationTimes }
    (Left _) -> return ()

renderBaseProgramChanged :: ImmutableRenderContext -> Context -> Int -> Either ParseError TextProgram -> Renderer

renderBaseProgramChanged irc c z (Left e) = setZoneError z (T.pack $ show e)

renderBaseProgramChanged irc c z (Right (TidalTextNotation x,y,_)) = do
  s <- get
  parseResult <- liftIO $ (return $! force (tidalParser x y)) `catch` (return . Left . (show :: SomeException -> String))
  let newParamPatterns = either (const $ paramPatterns s) (\p -> insert z p (paramPatterns s)) parseResult
  liftIO $ either (putStrLn) (const $ return ()) parseResult -- print new errors to console
  let newErrors = either (\e -> insert z (T.pack e) (errors (info s))) (const $ delete z (errors (info s))) parseResult
  modify' $ \x -> x { paramPatterns = newParamPatterns, info = (info s) { errors = newErrors} }

renderBaseProgramChanged irc c z (Right (Punctual,x,_)) = parsePunctualNotation' irc c z x

renderBaseProgramChanged irc c z (Right (Hydra,x,_)) = parseHydra irc c z x

renderBaseProgramChanged irc c z (Right (CineCer0,x,eTime)) = do
  let parseResult :: Either String CineCer0.Spec = CineCer0.cineCer0 eTime $ T.unpack x -- Either String CineCer0Spec
  when (isRight parseResult) $ do
    let spec :: CineCer0.Spec = fromRight (CineCer0.emptySpec eTime) parseResult
    s <- get
    modify' $ \x -> x { cineCer0Specs = insert z spec (cineCer0Specs s) }
    clearZoneError z
  when (isLeft parseResult) $ do
    let err = fromLeft "" parseResult
    setZoneError z (T.pack err)

renderBaseProgramChanged irc c z (Right (TimeNot,x,eTime)) = do
  let parseResult = TimeNot.runCanonParser $ T.unpack x
  case parseResult of
    (Right p) -> do
      clearZoneError z
      s <- get
      modify' $ \x -> x { timeNots = insert z p (timeNots s) }
    (Left e) -> do
      liftIO $ putStrLn (show e)
      setZoneError z (T.pack $ show e)

renderBaseProgramChanged irc c z (Right (Seis8s,x,eTime)) = do
  let parseResult = Seis8s.parseLang $ T.unpack x
  case parseResult of
    Right p -> do
      clearZoneError z
      s <- get
      modify' $ \x -> x { seis8ses = insert z p (seis8ses s) }
    Left e -> do
      liftIO $ putStrLn (show e)
      setZoneError z (T.pack $ show e)

renderBaseProgramChanged irc c z _ = setZoneError z "renderBaseProgramChanged: no match for base language"

parsePunctualNotation :: ImmutableRenderContext -> Context -> Int -> (Text -> Either ParseError Punctual.Program) -> Text -> Renderer
parsePunctualNotation irc c z p t = do
  s <- get
  let parseResult = p t
  case parseResult of
    Right punctualProgram -> punctualProgramChanged irc c z punctualProgram
    Left _ -> return ()
  let newErrors = either (\e -> insert z (T.pack $ show e) (errors (info s))) (const $ delete z (errors (info s))) parseResult
  modify' $ \x -> x { info = (info s) { errors = newErrors }}

parsePunctualNotation' :: ImmutableRenderContext -> Context -> Int -> Text -> Renderer
parsePunctualNotation' irc c z t = do
  s <- get
  let evalTime = utcTimeToAudioSeconds (wakeTimeSystem s, wakeTimeAudio s) $ renderStart s -- :: AudioTime/Double
  parseResult <- liftIO $ try $ return $! Punctual.parse evalTime t
  parseResult' <- case parseResult of
    Right (Right punctualProgram) -> do
      punctualProgramChanged irc c z punctualProgram
      return (Right punctualProgram)
    Right (Left parseErr) -> return (Left $ T.pack $ show parseErr)
    Left exception -> return (Left $ T.pack $ show (exception :: SomeException))
  let newErrors = either (\e -> insert z e (errors (info s))) (const $ delete z (errors (info s))) parseResult'
  modify' $ \x -> x { info = (info s) { errors = newErrors }}

parseHydra :: ImmutableRenderContext -> Context -> Int -> Text -> Renderer
parseHydra irc c z t = do
 s <- get
 parseResult <- liftIO $ try $ return $! Hydra.parseHydra t
 case parseResult of
   Right (Right stmts) -> do
     clearZoneError z
     let x = IntMap.lookup z $ hydras s
     hydra <- case x of
       Just h -> return h
       Nothing -> do
         h <- liftIO $ Hydra.newHydra $ hydraCanvas s
         modify' $ \x -> x { hydras = IntMap.insert z h (hydras x)}
         return h
     -- liftIO $ Hydra.setResolution hydra 1280 720
     liftIO $ Hydra.evaluate hydra stmts
   Right (Left parseErr) -> setZoneError z (T.pack $ show parseErr)
   Left exception -> setZoneError z (T.pack $ show (exception :: SomeException))

punctualProgramChanged :: ImmutableRenderContext -> Context -> Int -> Punctual.Program -> Renderer
punctualProgramChanged irc c z p = do
  s <- get
  -- A. update PunctualW (audio state) in response to new, syntactically correct program
  let (mainBusIn,_,_,_,_) = mainBus irc
  ac <- liftAudioIO $ audioContext
  t <- liftAudioIO $ audioTime
  let prevPunctualW = findWithDefault (Punctual.emptyPunctualW ac mainBusIn 2) z (punctuals s)
  let tempo' = tempo $ ensemble $ ensembleC c
  let beat0 = utcTimeToAudioSeconds (wakeTimeSystem s, wakeTimeAudio s) $ origin tempo'
  let cps' = freq tempo'
  newPunctualW <- liftIO $ do
    runAudioContextIO ac $ Punctual.updatePunctualW prevPunctualW (beat0,realToFrac cps') p
    `catch` (\e -> putStrLn (show (e :: SomeException)) >> return prevPunctualW)
  modify' $ \x -> x { punctuals = insert z newPunctualW (punctuals s)}
  -- B. update Punctual WebGL state in response to new, syntactically correct program
  pWebGL <- gets punctualWebGL
  newWebGL <- liftIO $
    Punctual.evaluatePunctualWebGL (glContext s) (beat0,realToFrac cps') z p pWebGL
    `catch` (\e -> putStrLn (show (e :: SomeException)) >> return pWebGL)
  modify' $ \x -> x { punctualWebGL = newWebGL }

renderTextProgramAlways :: ImmutableRenderContext -> Context -> Int -> UTCTime -> Renderer
renderTextProgramAlways irc c z eTime = do
  s <- get
  let baseNotation = IntMap.lookup z $ baseNotations s
  renderBaseProgramAlways irc c z eTime $ baseNotation

renderBaseProgramAlways :: ImmutableRenderContext -> Context -> Int -> UTCTime -> Maybe TextNotation -> Renderer
renderBaseProgramAlways irc c z _ (Just (TidalTextNotation _)) = renderControlPattern irc c z
renderBaseProgramAlways irc c z _ (Just TimeNot) = do
  s <- get
  let p = IntMap.lookup z $ timeNots s
  case p of
    (Just p') -> do
      let theTempo = (tempo . ensemble . ensembleC) c
      let eTime = IntMap.findWithDefault (wakeTimeSystem s) z $ evaluationTimes s
      let wStart = renderStart s
      let wEnd = renderEnd s
      let oTime = firstCycleStartAfter theTempo eTime
      pushNoteEvents $ fmap TimeNot.mapForEstuary $ TimeNot.render oTime p' wStart wEnd
    Nothing -> return ()
renderBaseProgramAlways irc c z _ (Just Seis8s) = do
  s <- get
  let p = IntMap.lookup z $ seis8ses s
  case p of
    Just p' -> do
      let theTempo = (tempo . ensemble . ensembleC) c
      let wStart = renderStart s
      let wEnd = renderEnd s
      pushNoteEvents $ Seis8s.render p' theTempo wStart wEnd
    Nothing -> return ()
renderBaseProgramAlways _ _ _ _ _ = return ()


renderControlPattern :: ImmutableRenderContext -> Context -> Int -> Renderer
renderControlPattern irc c z = when (webDirtOn c || superDirtOn c) $ do
  s <- get
  let controlPattern = IntMap.lookup z $ paramPatterns s -- :: Maybe ControlPattern
  case controlPattern of
    Just controlPattern' -> do
      let lt = renderStart s
      let rp = renderPeriod s
      let tempo' = tempo $ ensemble $ ensembleC c
      newEvents <- liftIO $ (return $! force $ renderTidalPattern lt rp tempo' controlPattern')
        `catch` (\e -> putStrLn (show (e :: SomeException)) >> return [])
      pushTidalEvents newEvents
    Nothing -> return ()


calculateZoneRenderTimes :: Int -> MovingAverage -> Renderer
calculateZoneRenderTimes z zrt = do
  s <- get
  let newAvgMap = insert z (getAverage zrt) (avgZoneRenderTime $ info s)
  modify' $ \x -> x { info = (info x) { avgZoneRenderTime = newAvgMap }}

calculateZoneAnimationTimes :: Int -> MovingAverage -> Renderer
calculateZoneAnimationTimes z zat = do
  s <- get
  let newAvgMap = insert z (getAverage zat) (avgZoneAnimationTime $ info s)
  modify' $ \x -> x { info = (info x) { avgZoneAnimationTime = newAvgMap }}

sleepIfNecessary :: Renderer
sleepIfNecessary = do
  s <- get
  let targetTime = addUTCTime (maxRenderLatency * (-1) - earlyWakeUp) (renderEnd s)
  tNow <- liftIO $ getCurrentTime
  let diff = diffUTCTime targetTime tNow
  when (diff > 0) $ liftIO $ threadDelay $ floor $ realToFrac $ diff * 1000000

forkRenderThreads :: ImmutableRenderContext -> MVar Context -> HTMLCanvasElement -> Punctual.GLContext -> HTMLCanvasElement -> MVar RenderInfo -> IO ()
forkRenderThreads irc ctxM cvsElement glCtx hCanvas riM = do
  t0Audio <- liftAudioIO $ audioTime
  t0System <- getCurrentTime
  irs <- initialRenderState (mic irc) (out irc) cvsElement glCtx hCanvas t0System t0Audio
  rsM <- newMVar irs
  void $ forkIO $ mainRenderThread irc ctxM riM rsM
  void $ forkIO $ animationThread irc ctxM rsM

mainRenderThread :: ImmutableRenderContext -> MVar Context -> MVar RenderInfo -> MVar RenderState -> IO ()
mainRenderThread irc ctxM riM rsM = do
  ctx <- readMVar ctxM
  rs <- takeMVar rsM
  rs' <- execStateT (render irc ctx) rs
  let rs'' = rs' {
    animationOn = canvasOn ctx,
    tempoCache = tempo $ ensemble $ ensembleC ctx,
    videoDivCache = videoDivElement ctx
    }
  putMVar rsM rs''
  swapMVar riM (info rs'') -- copy RenderInfo from state into MVar for instant reading elsewhere
  _ <- execStateT sleepIfNecessary rs''
  mainRenderThread irc ctxM riM rsM

animationThread :: ImmutableRenderContext -> MVar Context -> MVar RenderState -> IO ()
animationThread irc ctxM rsM = void $ inAnimationFrame ContinueAsync $ \_ -> do
  rs <- readMVar rsM
  when (animationOn rs) $ do
    rs' <- takeMVar rsM
    rs'' <- execStateT renderAnimation rs'
    putMVar rsM rs''
  animationThread irc ctxM rsM

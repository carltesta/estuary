module Estuary.Types.RenderState where

import Data.Time.Clock
import qualified Data.Map as Map
import Data.IntMap.Strict
import qualified Sound.Tidal.Context as Tidal
import qualified Sound.Punctual.PunctualW as Punctual
import qualified Sound.Punctual.WebGL as Punctual
import qualified Sound.Punctual.Resolution as Punctual
import Sound.MusicW.AudioContext
import Sound.MusicW.Node as MusicW
import GHCJS.DOM.Types (HTMLCanvasElement,HTMLDivElement)
import Data.Text (Text)
import Sound.Punctual.GL
import Data.Tempo
import Data.IORef

import Estuary.Types.Definition
import Estuary.Types.RenderInfo
import Estuary.Types.NoteEvent
import Estuary.Types.MovingAverage
import Estuary.Types.TextNotation
import qualified Estuary.Languages.CineCer0.CineCer0State as CineCer0
import qualified Estuary.Languages.CineCer0.Spec as CineCer0
import qualified Estuary.Languages.CineCer0.Parser as CineCer0
import qualified Sound.TimeNot.AST as TimeNot
-- import qualified Sound.Seis8s.Program as Seis8s
import qualified Estuary.Languages.Hydra.Render as Hydra
import Estuary.Languages.JSoLang


data RenderState = RenderState {
  wakeTimeAudio :: !Double,
  wakeTimeSystem :: !UTCTime,
  renderStart :: !UTCTime,
  renderPeriod :: !NominalDiffTime,
  renderEnd :: !UTCTime,
  cachedDefs :: !DefinitionMap,
  paramPatterns :: !(IntMap Tidal.ControlPattern),
  noteEvents :: ![NoteEvent],
  tidalEvents :: ![(UTCTime,Tidal.ValueMap)],
  baseNotations :: !(IntMap TextNotation),
  punctuals :: !(IntMap Punctual.PunctualW),
  punctualWebGL :: Punctual.PunctualWebGL,
  cineCer0Specs :: !(IntMap CineCer0.Spec),
  cineCer0States :: !(IntMap CineCer0.CineCer0State),
  timeNots :: IntMap TimeNot.Program,
  -- seis8ses :: IntMap Seis8s.Program,
  hydras :: IntMap Hydra.Hydra,
  evaluationTimes :: IntMap UTCTime, -- this is probably temporary
  renderTime :: !MovingAverage,
  wakeTimeAnimation :: !UTCTime,
  animationDelta :: !MovingAverage, -- time between frame starts, ie. 1/FPS
  animationTime :: !MovingAverage, -- time between frame start and end of drawing operations
  zoneRenderTimes :: !(IntMap MovingAverage),
  zoneAnimationTimes :: !(IntMap MovingAverage),
  info :: !RenderInfo,
  glContext :: GLContext,
  canvasElement :: HTMLCanvasElement,
  hydraCanvas :: HTMLCanvasElement,
  videoDivCache :: Maybe HTMLDivElement,
  tempoCache :: Tempo,
  jsoLangs :: Map.Map Text JSoLang,
  valueMap :: Tidal.ValueMap
  }

-- Map.mapKeys T.unpack -- Map Text a -> Map String a
-- fmap Tidal.toValue ... -- Map a Double -> Map a Value

initialRenderState :: MusicW.Node -> MusicW.Node -> HTMLCanvasElement -> GLContext -> HTMLCanvasElement -> UTCTime -> AudioTime -> IO RenderState
initialRenderState pIn pOut cvsElement glCtx hCanvas t0System t0Audio = do
  pWebGL <- Punctual.newPunctualWebGL (Just pIn) (Just pOut) Punctual.HD 1.0 hCanvas glCtx
  return $ RenderState {
    wakeTimeSystem = t0System,
    wakeTimeAudio = t0Audio,
    renderStart = t0System,
    renderPeriod = 0,
    renderEnd = t0System,
    cachedDefs = empty,
    paramPatterns = empty,
    noteEvents = [],
    tidalEvents = [],
    baseNotations = empty,
    punctuals = empty,
    punctualWebGL = pWebGL,
    cineCer0Specs = empty,
    cineCer0States = empty,
    timeNots = empty,
    -- seis8ses = empty,
    hydras = empty,
    evaluationTimes = empty,
    renderTime = newAverage 20,
    wakeTimeAnimation = t0System,
    animationDelta = newAverage 20,
    animationTime = newAverage 20,
    zoneRenderTimes = empty,
    zoneAnimationTimes = empty,
    info = emptyRenderInfo,
    glContext = glCtx,
    canvasElement = cvsElement,
    hydraCanvas = hCanvas,
    videoDivCache = Nothing,
    tempoCache = Tempo { freq = 0.5, time = t0System, count = 0 },
    jsoLangs = Map.empty,
    valueMap = Map.empty
  }

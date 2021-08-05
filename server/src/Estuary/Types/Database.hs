{-# LANGUAGE OverloadedStrings, DeriveGeneric #-}

module Estuary.Types.Database where

import Database.SQLite.Simple
import Database.SQLite.Simple.FromRow
import Database.SQLite.Simple.ToRow
import Database.SQLite.Simple.FromField
import Database.SQLite.Simple.ToField
import Database.SQLite.Simple.Ok
import Data.Map as Map
import Data.IntMap as IntMap
import Data.Time.Clock
import Data.Aeson
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as T
import qualified Data.Text.Lazy as Lazy
import qualified Data.Text.Lazy.Encoding as Lazy
import TextShow
import GHC.Generics
import Data.Aeson
import Control.Concurrent.STM
import Control.Concurrent

import Estuary.Types.View
import Estuary.Types.EnsembleS
import qualified Estuary.Types.Ensemble as Ensemble
import Estuary.Types.ServerState

openDatabase :: IO Connection
openDatabase = do
  c <- open "Estuary.db"
  createEnsembleTable c
  putStrLn "database opened"
  return c

closeDatabase :: Connection -> IO ()
closeDatabase = close

createEnsembleTable :: Connection -> IO ()
createEnsembleTable c = do
  execute_ c "CREATE TABLE IF NOT EXISTS ensembles (name TEXT NOT NULL, json TEXT, PRIMARY KEY (name))"

data EnsembleD = EnsembleD {
  ensemble :: Ensemble.Ensemble,
  ownerPassword :: Text,
  joinPassword :: Text,
  creationTime :: UTCTime,
  expiry :: Maybe NominalDiffTime,
  lastActionTime :: UTCTime
  } deriving (Generic)

instance ToJSON EnsembleD
instance FromJSON EnsembleD

ensembleStoEnsembleD :: EnsembleS -> IO EnsembleD
ensembleStoEnsembleD x = do
  t <- atomically $ readTempo x
  zs <- atomically $ readZones x
  vs <- atomically $ readViews x
  rs <- atomically $ readResourceOps x
  lat <- atomically $ readTVar $ Estuary.Types.EnsembleS.lastActionTime x
  let e = Ensemble.Ensemble {
    Ensemble.ensembleName = Estuary.Types.EnsembleS.ensembleName x,
    Ensemble.tempo = t,
    Ensemble.zones = zs,
    Ensemble.views = vs,
    Ensemble.resourceOps = rs,
    Ensemble.chats = [],
    Ensemble.participants = Map.empty,
    Ensemble.anonymousParticipants = 0
  }
  return $ EnsembleD {
    ensemble = e,
    Estuary.Types.Database.ownerPassword = Estuary.Types.EnsembleS.ownerPassword x,
    Estuary.Types.Database.joinPassword = Estuary.Types.EnsembleS.joinPassword x,
    Estuary.Types.Database.creationTime = Estuary.Types.EnsembleS.creationTime x,
    Estuary.Types.Database.expiry = Estuary.Types.EnsembleS.expiry x,
    Estuary.Types.Database.lastActionTime = lat
  }

ensembleDtoEnsembleS :: EnsembleD -> IO EnsembleS
ensembleDtoEnsembleS x = do
  t <- atomically $ newTVar (Ensemble.tempo (ensemble x))
  let zs = Ensemble.zones (ensemble x)
  zs' <- atomically (mapM newTVar zs >>= newTVar)
  let vs = Ensemble.views (ensemble x)
  vs' <- atomically (mapM newTVar vs >>= newTVar)
  rs' <- atomically $ newTVar (Ensemble.resourceOps (ensemble x))
  lat <- atomically $ newTVar $ Estuary.Types.Database.lastActionTime x
  connectionsTvar <- atomically $ newTVar IntMap.empty
  namedConnectionsTvar <- atomically $ newTVar IntMap.empty
  anonymousConnectionsTvar <- atomically $ newTVar 0
  return $ EnsembleS {
    Estuary.Types.EnsembleS.ensembleName = Ensemble.ensembleName $ ensemble x,
    Estuary.Types.EnsembleS.connections = connectionsTvar,
    Estuary.Types.EnsembleS.namedConnections = namedConnectionsTvar,
    Estuary.Types.EnsembleS.anonymousConnections = anonymousConnectionsTvar,
    Estuary.Types.EnsembleS.ownerPassword = Estuary.Types.Database.ownerPassword x,
    Estuary.Types.EnsembleS.joinPassword = Estuary.Types.Database.joinPassword x,
    Estuary.Types.EnsembleS.creationTime = Estuary.Types.Database.creationTime x,
    Estuary.Types.EnsembleS.expiry = Estuary.Types.Database.expiry x,
    Estuary.Types.EnsembleS.lastActionTime = lat,
    tempo = t,
    zones = zs',
    views = vs',
    resourceOps = rs'
  }

writeEnsemble :: Connection -> EnsembleS -> IO ()
writeEnsemble c e = do
  e' <- ensembleStoEnsembleD e
  let eName = Estuary.Types.EnsembleS.ensembleName e
  execute c "REPLACE INTO ensembles (name,json) VALUES (?,?)" (eName,e')

writeAllEnsembles :: Connection -> ServerState -> IO Int
writeAllEnsembles c ss = do
  x <- atomically $ readTVar $ ensembles ss
  xs <- mapM readTVarIO x
  mapM_ (writeEnsemble c) xs
  return $ Map.size xs

deleteEnsemble :: Connection -> Text -> IO ()
deleteEnsemble c eName = execute c "DELETE FROM ensembles WHERE name=?" (Only eName)

readEnsembles :: Connection -> IO (Map Text EnsembleS)
readEnsembles c = do
  r <- query_ c "SELECT name,json FROM ensembles" -- [(n,j)]
  mapM ensembleDtoEnsembleS $ Map.fromList r

instance ToField EnsembleD where
  toField = SQLText . Lazy.toStrict . Lazy.decodeUtf8 . encode

instance FromField EnsembleD where
  fromField = f . eitherDecode . g . fieldData
    where g (SQLText t) = Lazy.encodeUtf8 $ Lazy.fromStrict t
          g _ = Lazy.encodeUtf8 ""
          f (Right x) = Database.SQLite.Simple.Ok.Ok x
          f (Left x) = error x

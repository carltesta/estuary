{-# LANGUAGE DeriveDataTypeable #-}

module Estuary.Types.EnsembleResponse where

import Data.Maybe (mapMaybe)
import Data.Ratio
import Text.JSON
import Text.JSON.Generic
import Data.Time
import Data.Text

import Estuary.Types.View
import Estuary.Types.Tempo
import Estuary.Types.Definition
import Estuary.Types.Participant

data EnsembleResponse =
  Chat Text Text | -- name message
  ZoneResponse Int Definition |
  ViewList [Text] |
  View Text View |
  DefaultView View |
  NewTempo Tempo UTCTime | -- the tempo plus the time it was sent by the server
  ParticipantJoins Text Participant |
  ParticipantUpdate Text Participant |
  ParticipantLeaves Text |
  AnonymousParticipants Int
  deriving (Data,Typeable)

instance JSON EnsembleResponse where
  showJSON = toJSON
  readJSON = fromJSON

justEditsInZone :: Int -> [EnsembleResponse] -> [Definition]
justEditsInZone z1 = mapMaybe f
  where
    f (ZoneResponse z2 a) | z1==z2 = Just a
    f _ = Nothing

justChats :: [EnsembleResponse] -> [(Text,Text)]
justChats = mapMaybe f
  where f (Chat x y) = Just (x,y)
        f _ = Nothing

justViews :: [EnsembleResponse] -> [(Text,View)]
justViews = mapMaybe f
  where f (View x y) = Just (x,y)
        f _ = Nothing

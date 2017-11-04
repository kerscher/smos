{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE OverloadedStrings #-}

module Smos.Draw
    ( smosDraw
    ) where

import Import

import Data.HashMap.Lazy (HashMap)
import qualified Data.HashMap.Lazy as HM
import qualified Data.Text as T
import Data.Time

import Brick.Types as B
import Brick.Widgets.Center as B
import Brick.Widgets.Core as B

import Smos.Data

import Smos.Cursor
import Smos.Cursor.Class
import Smos.Cursor.Text
import Smos.Cursor.TextField
import Smos.Style
import Smos.Types

smosDraw :: SmosState -> [Widget ResourceName]
smosDraw SmosState {..} = [maybe drawNoContent renderCursor smosStateCursor]
  where
    renderCursor :: ACursor -> Widget ResourceName
    renderCursor cur = drawForest msel for <=> str (show rsel)
      where
        msel = Just rsel
        rsel = reverse $ selection $ selectAnyCursor cur
        for = smosFileForest $ rebuild cur

drawNoContent :: Widget n
drawNoContent =
    B.vCenterLayer $
    B.vBox $
    map B.hCenterLayer
        [ str "SMOS"
        , str " "
        , str "version 0.0.0"
        , str "by Tom Sydney Kerckhove"
        , str "Smos is open source and freely distributable"
        ]

drawForest :: Maybe [Int] -> SmosForest -> Widget ResourceName
drawForest = foldForestSel drawTree $ padLeft (Pad 2) . B.vBox . map snd

drawTree :: Maybe [Int] -> SmosTree -> Widget ResourceName
drawTree msel SmosTree {..} = foldTreeSel drawEntry drawTree (<=>)

drawEntry :: Maybe [Int] -> Entry -> Widget ResourceName
drawEntry msel Entry {..} =
    withSel msel $
    B.vBox
        [ B.hBox $
          intersperse (B.txt " ") $
          [B.txt ">"] ++
          maybe [] pure (drawTodoState (drillSel msel 0) <$> entryState) ++
          [ drawHeader (drillSel msel 1) entryHeader
          , drawTags (drillSel msel 2) entryTags
          ]
        , drawTimestamps (drillSel msel 3) entryTimestamps
        -- , drawProperties (drillSel msel 4) entryProperties
        , drawContents (drillSel msel 5) entryContents
        , drawLogbook entryLogbook
        ]

drawTodoState :: Maybe [Int] -> TodoState -> Widget ResourceName
drawTodoState msel ts =
    withSel msel $
    withAttr todoStateAttr $
    withAttr (todoStateSpecificAttr ts) $ B.txt $ todoStateText ts

drawHeader :: Maybe [Int] -> Header -> Widget ResourceName
drawHeader msel Header {..} = withAttr headerAttr $ withTextSel msel headerText

drawContents :: Maybe [Int] -> Maybe Contents -> Widget ResourceName
drawContents msel mcon =
    case mcon of
        Nothing -> emptyWidget
        Just Contents {..} ->
            withAttr contentsAttr $ withTextFieldSel msel contentsText

drawTags :: Maybe [Int] -> [Tag] -> Widget ResourceName
drawTags msel ts =
    withSel msel $
    B.hBox $
    addColons $
    flip map (zip [0 ..] ts) $ \(ix, t) -> drawTag (drillSel msel ix) t
  where
    addColons ls =
        case ls of
            [] -> []
            _ -> colon : intersperse colon ls ++ [colon]
      where
        colon = B.txt ":"

drawTag :: Maybe [Int] -> Tag -> Widget ResourceName
drawTag msel Tag {..} = withAttr tagAttr $ withTextSel msel tagText

drawTimestamps ::
       Maybe [Int] -> HashMap TimestampName UTCTime -> Widget ResourceName
drawTimestamps msel tss =
    withSel msel $
    B.vBox $
    flip map (HM.toList tss) $ \(k, ts) ->
        B.hBox [B.txt $ timestampNameText k, B.txt ": ", drawTimestamp ts]

drawTimestamp :: UTCTime -> Widget n
drawTimestamp = B.str . formatTime defaultTimeLocale "%F %R"

drawLogbook :: Logbook -> Widget n
drawLogbook LogEnd = B.emptyWidget
drawLogbook (LogEntry b e l) =
    B.hBox [str "[", drawTimestamp b, str "]--[", drawTimestamp e, str "]"] <=>
    drawLogbook l
drawLogbook (LogOpenEntry b l) =
    B.hBox [str "[", drawTimestamp b, str "]"] <=> drawLogbook l

withSel :: Maybe [Int] -> Widget n -> Widget n
withSel msel =
    case msel of
        Nothing -> id
        Just [] -> withAttr selectedAttr
        Just _ -> id

withTextSel :: Maybe [Int] -> Text -> Widget ResourceName
withTextSel =
    foldTextSel $ \mix t ->
        case mix of
            Nothing -> B.txt t
            Just ix_ ->
                withAttr selectedAttr $
                B.showCursor textCursorName (B.Location (ix_, 0)) $ B.txt t

withTextFieldSel :: Maybe [Int] -> Text -> Widget ResourceName
withTextFieldSel =
    foldTextFieldSel $ \mixs t ->
        let ls = T.splitOn "\n" t
            textOrSpace t_ =
                if T.null t
                    then B.txt " "
                    else B.txt t_
            tw = B.vBox $ map textOrSpace ls
        in case mixs of
               Nothing -> tw
               Just (xix_, yix_) ->
                   withAttr selectedAttr $
                   B.showCursor textCursorName (B.Location (xix_, yix_)) tw

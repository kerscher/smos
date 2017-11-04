{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeFamilies #-}

module Smos.Cursor
    ( AnyCursor(..)
    , makeAnyCursor
    , reselect
    , ACursor(..)
    , selectACursor
    , selectAnyCursor
    , Rebuild(..)
    , Build(..)
    , ForestCursor
    , makeForestCursor
    , foldForestSel
    , forestCursorParent
    , forestCursorElems
    , forestCursorSelectIx
    , forestCursorSelectFirst
    , forestCursorSelectLast
    , forestCursorInsertAt
    , forestCursorInsertAtStart
    , forestCursorInsertAtEnd
    , TreeCursor
    , treeCursorParent
    , treeCursorPrevElemens
    , treeCursorNextElemens
    , treeCursorIndex
    , treeCursorEntry
    , treeCursorForest
    , foldTreeSel
    , treeCursorSelectPrev
    , treeCursorSelectNext
    , treeCursorEntryL
    , treeCursorForestL
    , treeCursorInsertAbove
    , treeCursorInsertBelow
    , treeCursorInsertChildAt
    , treeCursorInsertChildAtStart
    , treeCursorInsertChildAtEnd
    , treeCursorDeleteCurrent
    , EntryCursor
    , entryCursorParent
    , entryCursorHeader
    , entryCursorContents
    , entryCursorState
    , entryCursorTags
    , entryCursorHeaderL
    , entryCursorContentsL
    , entryCursorStateL
    , entryCursorTagsL
    , entryCursorLogbookL
    , entryCursorClockIn
    , HeaderCursor
    , headerCursor
    , headerCursorParent
    , headerCursorHeader
    , headerCursorTextCursorL
    , headerCursorInsert
    , headerCursorAppend
    , headerCursorRemove
    , headerCursorDelete
    , headerCursorLeft
    , headerCursorRight
    , headerCursorStart
    , headerCursorEnd
    , ContentsCursor
    , emptyContentsCursor
    , contentsCursor
    , contentsCursorParent
    , contentsCursorContents
    , contentsCursorContentsL
    , contentsCursorSetContents
    , contentsCursorTextFieldL
    , contentsCursorInsert
    , contentsCursorAppend
    , contentsCursorNewline
    , contentsCursorRemove
    , contentsCursorDelete
    , contentsCursorLeft
    , contentsCursorRight
    , contentsCursorUp
    , contentsCursorDown
    , contentsCursorStart
    , contentsCursorEnd
    , StateCursor
    , stateCursor
    , stateCursorParent
    , stateCursorState
    , stateCursorClear
    , stateCursorSetState
    , TagsCursor
    , tagsCursor
    , tagsCursorParent
    , tagsCursorTags
    , tagsCursorSelectFirst
    , tagsCursorSelectLast
    , tagsCursorInsertAtStart
    , tagsCursorAppendAtEnd
    , TagCursor
    , tagCursorParent
    , tagCursorTag
    , tagCursorInsert
    , tagCursorAppend
    , tagCursorRemove
    , tagCursorDelete
    , tagCursorLeft
    , tagCursorRight
    , tagCursorStart
    , tagCursorEnd
    , tagCursorSelectPrev
    , tagCursorSelectNext
    ) where

import Import

import Data.HashMap.Lazy (HashMap)
import qualified Data.Text as T
import Data.Time

import Lens.Micro

import Smos.Cursor.Class
import Smos.Cursor.Text
import Smos.Cursor.TextField
import Smos.Data

data AnyCursor
    = AnyForest ForestCursor
    | AnyTree TreeCursor
    | AnyEntry EntryCursor
    | AnyHeader HeaderCursor
    | AnyContents ContentsCursor
    | AnyState StateCursor
    | AnyTags TagsCursor
    | AnyTag TagCursor
    deriving (Show, Eq, Generic)

instance Validity AnyCursor

instance Rebuild AnyCursor where
    type ReBuilding AnyCursor = SmosFile
    rebuild (AnyForest fc) = rebuild fc
    rebuild (AnyTree tc) = rebuild tc
    rebuild (AnyEntry ec) = rebuild ec
    rebuild (AnyHeader hc) = rebuild hc
    rebuild (AnyContents cc) = rebuild cc
    rebuild (AnyState sc) = rebuild sc
    rebuild (AnyTags tsc) = rebuild tsc
    rebuild (AnyTag tc) = rebuild tc
    selection (AnyForest fc) = selection fc
    selection (AnyTree tc) = selection tc
    selection (AnyEntry ec) = selection ec
    selection (AnyHeader hc) = selection hc
    selection (AnyContents cc) = selection cc
    selection (AnyState sc) = selection sc
    selection (AnyTags tsc) = selection tsc
    selection (AnyTag tc) = selection tc

data ACursor
    = AnEntry EntryCursor
    | AHeader HeaderCursor
    | AContents ContentsCursor
    | AState StateCursor
    | ATag TagCursor
    deriving (Show, Eq, Generic)

instance Validity ACursor

instance Rebuild ACursor where
    type ReBuilding ACursor = SmosFile
    rebuild (AnEntry ec) = rebuild ec
    rebuild (AHeader hc) = rebuild hc
    rebuild (AContents cc) = rebuild cc
    rebuild (AState sc) = rebuild sc
    rebuild (ATag tc) = rebuild tc
    selection (AnEntry ec) = selection ec
    selection (AHeader hc) = selection hc
    selection (AContents cc) = selection cc
    selection (AState sc) = selection sc
    selection (ATag tc) = selection tc

makeAnyCursor :: SmosFile -> AnyCursor
makeAnyCursor SmosFile {..} = AnyForest $ makeForestCursor smosFileForest

reselect :: [Int] -> SmosFile -> AnyCursor
reselect s = go (reverse s) . makeAnyCursor
  where
    go sel (AnyForest fc) = gof sel fc
    go sel (AnyTree tc) = got sel tc
    go sel (AnyEntry ec) = goe sel ec
    go sel (AnyHeader hc) = goh sel hc
    go sel (AnyContents cc) = goc sel cc
    go sel (AnyState sc) = gos sel sc
    go sel (AnyTags tsc) = gotgs sel tsc
    go sel (AnyTag tc) = gotg sel tc
    gof sel fc =
        withSel sel (AnyForest fc) $ \ix_ sel_ ->
            fromMaybe (AnyForest fc) $
            got sel_ <$> forestCursorElems fc `atMay` ix_
    got sel tc =
        withSel sel (AnyTree tc) $ \ix_ sel_ ->
            case ix_ of
                0 -> goe sel_ $ treeCursorEntry tc
                1 -> gof sel_ $ treeCursorForest tc
                _ -> AnyTree tc
    goe sel e =
        withSel sel (AnyEntry e) $ \ix_ sel_ ->
            case ix_ of
                0 -> gos sel_ $ entryCursorState e
                1 -> goh sel_ $ entryCursorHeader e
                2 -> gotgs sel_ $ entryCursorTags e
                -- 3: timestamps
                -- 4: properties
                5 -> maybe (AnyEntry e) (goc sel_) $ entryCursorContents e
                -- 6: clock
                _ -> AnyEntry e
    goh _ = AnyHeader
    goc _ = AnyContents
    gos _ = AnyState
    gotgs sel tsc =
        withSel sel (AnyTags tsc) $ \ix_ sel_ ->
            fromMaybe (AnyTags tsc) $
            gotg sel_ <$> tagsCursorTags tsc `atMay` ix_
    gotg _ = AnyTag
    withSel :: [Int] -> a -> (Int -> [Int] -> a) -> a
    withSel sel a func =
        case sel of
            [] -> a
            (ix_:rest) -> func ix_ rest

selectACursor :: AnyCursor -> Maybe ACursor
selectACursor ac =
    case ac of
        AnyForest fc -> AnEntry . treeCursorEntry <$> forestCursorSelectFirst fc
        AnyTree tc -> Just $ AnEntry $ treeCursorEntry tc
        AnyEntry ec -> Just $ AnEntry ec
        AnyHeader hc -> Just $ AHeader hc
        AnyContents cc -> Just $ AContents cc
        AnyState sc -> Just $ AState sc
        AnyTags tsc -> ATag <$> tagsCursorSelectFirst tsc
        AnyTag tc -> Just $ ATag tc

selectAnyCursor :: ACursor -> AnyCursor
selectAnyCursor ac =
    case ac of
        AnEntry hc -> AnyEntry hc
        AHeader hc -> AnyHeader hc
        AContents cc -> AnyContents cc
        AState hc -> AnyState hc
        ATag tc -> AnyTag tc

data ForestCursor = ForestCursor
    { forestCursorParent :: Maybe TreeCursor
    , forestCursorElems :: [TreeCursor]
    }

instance Validity ForestCursor where
    isValid a = isValid (build a) && isValid (rebuild a)
    validate a = (build a <?!> "build") <> (rebuild a <?!> "rebuild")

instance Show ForestCursor where
    show ForestCursor {..} =
        unlines
            $(case forestCursorParent of
                  Nothing -> "Nothing"
                  Just _ -> "Just [..]") :
        map ((" -" ++) . show) forestCursorElems

instance Eq ForestCursor where
    (==) = ((==) `on` build) &&& ((==) `on` rebuild)

instance Rebuild ForestCursor where
    type ReBuilding ForestCursor = SmosFile
    rebuild fc =
        case forestCursorParent fc of
            Nothing -> SmosFile $ build fc
            Just pc -> rebuild pc
    selection ForestCursor {..} =
        case forestCursorParent of
            Nothing -> []
            Just p -> 1 : selection p

instance Build ForestCursor where
    type Building ForestCursor = SmosForest
    build = SmosForest . map build . forestCursorElems

makeForestCursor :: SmosForest -> ForestCursor
makeForestCursor = forestCursor Nothing

forestCursor :: Maybe TreeCursor -> SmosForest -> ForestCursor
forestCursor mpar sf = fc
  where
    fc =
        ForestCursor
        { forestCursorParent = mpar
        , forestCursorElems = treeElems fc $ smosTrees sf
        }

foldForestSel ::
       (Maybe [Int] -> SmosTree -> r)
    -> ([(Int, r)] -> r)
    -> Maybe [Int]
    -> SmosForest
    -> r
foldForestSel rFunc combFunc msel SmosForest {..} =
    combFunc $
    flip map (zip [0 ..] smosTrees) $ \(ix_, st) ->
        (ix_, rFunc (drillSel msel ix_) st)

forestElemsL ::
       Functor f
    => ([TreeCursor] -> f [TreeCursor])
    -> ForestCursor
    -> f ForestCursor
forestElemsL = lens getter setter
  where
    getter = forestCursorElems
    setter ForestCursor {..} elems = fc'
      where
        fc' =
            ForestCursor
            { forestCursorParent =
                  rebuildForestParentCursor (const fc') forestCursorParent
            , forestCursorElems = elems
            }

rebuildForestParentCursor ::
       (ForestCursor -> ForestCursor) -> Maybe TreeCursor -> Maybe TreeCursor
rebuildForestParentCursor func mtc =
    (\tc -> tc & treeCursorForestL %~ func) <$> mtc

forestCursorSelectIx :: ForestCursor -> Int -> Maybe TreeCursor
forestCursorSelectIx fc = atMay $ forestCursorElems fc

forestCursorSelectFirst :: ForestCursor -> Maybe TreeCursor
forestCursorSelectFirst fc =
    case forestCursorElems fc of
        [] -> Nothing
        (tc:_) -> Just tc

forestCursorSelectLast :: ForestCursor -> Maybe TreeCursor
forestCursorSelectLast fc =
    case reverse $ forestCursorElems fc of
        [] -> Nothing
        (tc:_) -> Just tc

forestCursorInsertAt :: Int -> SmosTree -> ForestCursor -> ForestCursor
forestCursorInsertAt ix_ newTree fc = fc'
  where
    fc' =
        fc & forestElemsL %~
        (\els ->
             treeElems fc' $
             map build (prevs els) ++ [newTree] ++ map build (nexts els))
    ffilter rel = filter ((`rel` ix_) . treeCursorIndex)
    prevs = ffilter (<)
    nexts = ffilter (>=)

forestCursorInsertAtStart :: SmosTree -> ForestCursor -> ForestCursor
forestCursorInsertAtStart = forestCursorInsertAt 0

forestCursorInsertAtEnd :: SmosTree -> ForestCursor -> ForestCursor
forestCursorInsertAtEnd t fc =
    forestCursorInsertAt (length $ forestCursorElems fc) t fc

data TreeCursor = TreeCursor
    { treeCursorParent :: ForestCursor
    , treeCursorPrevElemens :: [TreeCursor] -- ^ In reverse order, so that the first element is the nearest.
    , treeCursorNextElemens :: [TreeCursor]
    , treeCursorIndex :: Int
    , treeCursorEntry :: EntryCursor
    , treeCursorForest :: ForestCursor
    }

instance Validity TreeCursor where
    isValid a = isValid (build a) && isValid (rebuild a)
    validate a = (build a <?!> "build") <> (rebuild a <?!> "rebuild")

instance Eq TreeCursor where
    (==) = ((==) `on` build) &&& ((==) `on` rebuild)

instance Rebuild TreeCursor where
    type ReBuilding TreeCursor = SmosFile
    rebuild = rebuild . treeCursorParent
    selection TreeCursor {..} =
        length treeCursorPrevElemens : selection treeCursorParent

instance Build TreeCursor where
    type Building TreeCursor = SmosTree
    build TreeCursor {..} =
        SmosTree
        {treeEntry = build treeCursorEntry, treeForest = build treeCursorForest}

instance Show TreeCursor where
    show TreeCursor {..} =
        unlines
            ("[..]" :
             map
                 (" |-" ++)
                 (concat
                      [ map (const "tree") treeCursorPrevElemens
                      , [ "---"
                        , unwords
                              [ show treeCursorIndex
                              , show $ build treeCursorEntry
                              , show $ build treeCursorForest
                              ]
                        , "---"
                        ]
                      , map (const "tree") treeCursorNextElemens
                      ]))

treeCursorEntryL ::
       Functor f => (EntryCursor -> f EntryCursor) -> TreeCursor -> f TreeCursor
treeCursorEntryL = lens getter setter
  where
    getter = treeCursorEntry
    setter tc ec = treeCursorModify (const ec) id tc

treeCursorForestL ::
       Functor f
    => (ForestCursor -> f ForestCursor)
    -> TreeCursor
    -> f TreeCursor
treeCursorForestL = lens getter setter
  where
    getter = treeCursorForest
    setter tc fc = treeCursorModify id (const fc) tc

treeCursorModify ::
       (EntryCursor -> EntryCursor)
    -> (ForestCursor -> ForestCursor)
    -> TreeCursor
    -> TreeCursor
treeCursorModify efunc ffunc tc = tc''
  where
    tc' =
        tc
        { treeCursorEntry = efunc $ treeCursorEntry tc
        , treeCursorForest = ffunc $ treeCursorForest tc
        }
    tcs =
        reverse (treeCursorPrevElemens tc) ++ [tc'] ++ treeCursorNextElemens tc
    trees = map build tcs
    fc = treeCursorParent tc & forestElemsL .~ els
    els = treeElems fc trees
    tc'' = els !! treeCursorIndex tc

treeElems :: ForestCursor -> [SmosTree] -> [TreeCursor]
treeElems fc sts = tcs
  where
    tcs = zipWith tc [0 ..] sts
    tc i st = cur
      where
        cur =
            TreeCursor
            { treeCursorParent = fc
            , treeCursorPrevElemens =
                  reverse $ filter ((< i) . treeCursorIndex) tcs
            , treeCursorNextElemens = filter ((> i) . treeCursorIndex) tcs
            , treeCursorIndex = i
            , treeCursorEntry = entryCursor cur $ treeEntry st
            , treeCursorForest = fc'
            }
        fc' = forestCursor (Just cur) (treeForest st)

foldTreeSel ::
       (Maybe [Int] -> Entry -> r)
    -> (Maybe [Int] -> SmosForest -> r)
    -> (r -> r -> r)
    -> Maybe [Int]
    -> SmosTree
    -> r
foldTreeSel eFunc fFunc combFunc msel SmosTree {..} =
    eFunc (drillSel msel 0) treeEntry `combFunc`
    fFunc (drillSel msel 1) treeForest

treeCursorSelectPrev :: TreeCursor -> Maybe TreeCursor
treeCursorSelectPrev tc =
    case treeCursorPrevElemens tc of
        [] -> Nothing
        (tc':_) -> Just tc'

treeCursorSelectNext :: TreeCursor -> Maybe TreeCursor
treeCursorSelectNext tc =
    case treeCursorNextElemens tc of
        [] -> Nothing
        (tc':_) -> Just tc'

treeCursorInsertAbove :: TreeCursor -> SmosTree -> TreeCursor
treeCursorInsertAbove tc t = fromJust $ forestCursorSelectIx newpar newIx
  where
    newIx = treeCursorIndex tc
    newpar = forestCursorInsertAt newIx t (treeCursorParent tc)

treeCursorInsertBelow :: TreeCursor -> SmosTree -> TreeCursor
treeCursorInsertBelow tc t =
    fromJust $ forestCursorSelectIx newpar $ treeCursorIndex tc + 1
  where
    newIx = treeCursorIndex tc + 1
    newpar = forestCursorInsertAt newIx t (treeCursorParent tc)

treeCursorInsertChildAt :: Int -> SmosTree -> TreeCursor -> TreeCursor
treeCursorInsertChildAt ix_ t tc =
    tc & treeCursorForestL %~ forestCursorInsertAt ix_ t

treeCursorInsertChildAtStart :: SmosTree -> TreeCursor -> TreeCursor
treeCursorInsertChildAtStart = treeCursorInsertChildAt 0

treeCursorInsertChildAtEnd :: SmosTree -> TreeCursor -> TreeCursor
treeCursorInsertChildAtEnd t tc =
    treeCursorInsertChildAt
        (length $ forestCursorElems $ treeCursorForest tc)
        t
        tc

treeCursorDeleteCurrent :: TreeCursor -> Either ForestCursor TreeCursor
treeCursorDeleteCurrent tc = tc''
  where
    tcs = reverse (treeCursorPrevElemens tc) ++ treeCursorNextElemens tc
    trees = map build tcs
    for = treeCursorParent tc & forestElemsL .~ els
    els = treeElems for trees
    tc'' =
        let ix_ = treeCursorIndex tc
        in maybe (Left for) Right $
           (els `atMay` ix_) `mplus` (els `atMay` (ix_ - 1))

data EntryCursor = EntryCursor
    { entryCursorParent :: TreeCursor
    , entryCursorHeader :: HeaderCursor
    , entryCursorContents :: Maybe ContentsCursor
    , entryCursorTimestamps :: HashMap TimestampName UTCTime
    , entryCursorState :: StateCursor
    , entryCursorTags :: TagsCursor
    , entryCursorLogbook :: Logbook
    }

instance Validity EntryCursor where
    isValid a = isValid (build a) && isValid (rebuild a)
    validate a = (build a <?!> "build") <> (rebuild a <?!> "rebuild")

instance Show EntryCursor where
    show EntryCursor {..} =
        unlines
            ("[Tree]" :
             map
                 (" |- " ++)
                 [ "[Header]: " ++ show (build entryCursorHeader)
                 , show entryCursorContents
                 , show entryCursorTimestamps
                 , "[State]: " ++ show (build entryCursorState)
                 , "[Tags]: " ++ show (build entryCursorTags)
                 , show entryCursorLogbook
                 ])

instance Eq EntryCursor where
    (==) = ((==) `on` build) &&& ((==) `on` rebuild)

instance Rebuild EntryCursor where
    type ReBuilding EntryCursor = SmosFile
    rebuild = rebuild . entryCursorParent
    selection EntryCursor {..} = 0 : selection entryCursorParent

instance Build EntryCursor where
    type Building EntryCursor = Entry
    build EntryCursor {..} =
        Entry
        { entryHeader = build entryCursorHeader
        , entryContents = build <$> entryCursorContents
        , entryTimestamps = entryCursorTimestamps
        , entryState = build entryCursorState
        , entryTags = build entryCursorTags
        , entryLogbook = entryCursorLogbook
        }

entryCursor :: TreeCursor -> Entry -> EntryCursor
entryCursor par Entry {..} = ec
  where
    ec =
        EntryCursor
        { entryCursorParent = par
        , entryCursorHeader = headerCursor ec entryHeader
        , entryCursorContents = contentsCursor ec <$> entryContents
        , entryCursorTimestamps = entryTimestamps
        , entryCursorState = stateCursor ec entryState
        , entryCursorTags = tagsCursor ec entryTags
        , entryCursorLogbook = entryLogbook
        }

foldEntrySel :: (Maybe [Int] -> TodoState -> r)
    -> (Maybe [Int] -> Header -> r)
    -> (Maybe [Int] -> [Tag] -> r)
    -> (Maybe [Int] -> HashMap TimestampName UTCTime -> r)
    -> (Maybe [Int] -> Contents -> r)
    -> (Maybe [Int] -> Logbook -> r)
    -> (r -> r->r->r->r->r->r) -> Entry -> r
foldEntrySel = undefined

entryCursorHeaderL ::
       Functor f
    => (HeaderCursor -> f HeaderCursor)
    -> EntryCursor
    -> f EntryCursor
entryCursorHeaderL = lens getter setter
  where
    getter = entryCursorHeader
    setter ec hc = ec'
      where
        ec' =
            ec
            { entryCursorParent = entryCursorParent ec & treeCursorEntryL .~ ec'
            , entryCursorHeader = hc
            , entryCursorContents =
                  (\ec_ -> ec_ {contentsCursorParent = ec'}) <$>
                  entryCursorContents ec
            , entryCursorState = (entryCursorState ec) {stateCursorParent = ec'}
            }

entryCursorContentsL ::
       Functor f
    => (Maybe ContentsCursor -> f (Maybe ContentsCursor))
    -> EntryCursor
    -> f EntryCursor
entryCursorContentsL = lens getter setter
  where
    getter = entryCursorContents
    setter ec mcc = ec'
      where
        ec' =
            ec
            { entryCursorParent = entryCursorParent ec & treeCursorEntryL .~ ec'
            , entryCursorState = (entryCursorState ec) {stateCursorParent = ec'}
            , entryCursorHeader =
                  (entryCursorHeader ec) {headerCursorParent = ec'}
            , entryCursorContents = mcc
            , entryCursorTags = (entryCursorTags ec) {tagsCursorParent = ec'}
            }

entryCursorStateL ::
       Functor f
    => (StateCursor -> f StateCursor)
    -> EntryCursor
    -> f EntryCursor
entryCursorStateL = lens getter setter
  where
    getter = entryCursorState
    setter ec hc = ec'
      where
        ec' =
            ec
            { entryCursorParent = entryCursorParent ec & treeCursorEntryL .~ ec'
            , entryCursorState = hc
            , entryCursorHeader =
                  (entryCursorHeader ec) {headerCursorParent = ec'}
            , entryCursorContents =
                  (\ec_ -> ec_ {contentsCursorParent = ec'}) <$>
                  entryCursorContents ec
            , entryCursorTags = (entryCursorTags ec) {tagsCursorParent = ec'}
            }

entryCursorTagsL ::
       Functor f => (TagsCursor -> f TagsCursor) -> EntryCursor -> f EntryCursor
entryCursorTagsL = lens getter setter
  where
    getter = entryCursorTags
    setter ec ts = ec'
      where
        ec' =
            ec
            { entryCursorParent = entryCursorParent ec & treeCursorEntryL .~ ec'
            , entryCursorState = (entryCursorState ec) {stateCursorParent = ec'}
            , entryCursorHeader =
                  (entryCursorHeader ec) {headerCursorParent = ec'}
            , entryCursorContents =
                  (\ec_ -> ec_ {contentsCursorParent = ec'}) <$>
                  entryCursorContents ec
            , entryCursorTags = ts
            }

entryCursorLogbookL ::
       Functor f => (Logbook -> f Logbook) -> EntryCursor -> f EntryCursor
entryCursorLogbookL = lens getter setter
  where
    getter = entryCursorLogbook
    setter ec lb = ec'
      where
        ec' =
            ec
            { entryCursorParent = entryCursorParent ec & treeCursorEntryL .~ ec'
            , entryCursorState = (entryCursorState ec) {stateCursorParent = ec'}
            , entryCursorHeader =
                  (entryCursorHeader ec) {headerCursorParent = ec'}
            , entryCursorContents =
                  (\ec_ -> ec_ {contentsCursorParent = ec'}) <$>
                  entryCursorContents ec
            , entryCursorTags = (entryCursorTags ec) {tagsCursorParent = ec'}
            , entryCursorLogbook = lb
            }

entryCursorClockIn :: UTCTime -> EntryCursor -> Maybe EntryCursor
entryCursorClockIn now = entryCursorLogbookL $ clockInAt now

data HeaderCursor = HeaderCursor
    { headerCursorParent :: EntryCursor
    , headerCursorHeader :: TextCursor
    }

instance Validity HeaderCursor where
    isValid a = isValid (build a) && isValid (rebuild a)
    validate a = (build a <?!> "build") <> (rebuild a <?!> "rebuild")

instance Show HeaderCursor where
    show HeaderCursor {..} =
        unlines ["[Entry]", " |-" ++ show (rebuild headerCursorHeader)]

instance Eq HeaderCursor where
    (==) = ((==) `on` build) &&& ((==) `on` rebuild)

instance Rebuild HeaderCursor where
    type ReBuilding HeaderCursor = SmosFile
    rebuild = rebuild . headerCursorParent
    selection HeaderCursor {..} =
        selection headerCursorHeader ++ [1] ++ selection headerCursorParent

instance Build HeaderCursor where
    type Building HeaderCursor = Header
    build HeaderCursor {..} = Header $ rebuild headerCursorHeader

headerCursor :: EntryCursor -> Header -> HeaderCursor
headerCursor par h =
    HeaderCursor
    { headerCursorParent = par
    , headerCursorHeader = makeTextCursor $ headerText h
    }

headerCursorTextCursorL ::
       Functor f
    => (TextCursor -> f TextCursor)
    -> HeaderCursor
    -> f HeaderCursor
headerCursorTextCursorL = lens getter setter
  where
    getter = headerCursorHeader
    setter hc tc = hc'
      where
        hc' =
            HeaderCursor
            { headerCursorParent =
                  headerCursorParent hc & entryCursorHeaderL .~ hc'
            , headerCursorHeader = tc
            }

headerCursorInsert :: Char -> HeaderCursor -> HeaderCursor
headerCursorInsert c = headerCursorTextCursorL %~ textCursorInsert c

headerCursorAppend :: Char -> HeaderCursor -> HeaderCursor
headerCursorAppend c = headerCursorTextCursorL %~ textCursorAppend c

headerCursorRemove :: HeaderCursor -> Maybe HeaderCursor
headerCursorRemove = headerCursorTextCursorL textCursorRemove

headerCursorDelete :: HeaderCursor -> Maybe HeaderCursor
headerCursorDelete = headerCursorTextCursorL textCursorDelete

headerCursorLeft :: HeaderCursor -> Maybe HeaderCursor
headerCursorLeft = headerCursorTextCursorL textCursorSelectPrev

headerCursorRight :: HeaderCursor -> Maybe HeaderCursor
headerCursorRight = headerCursorTextCursorL textCursorSelectNext

headerCursorStart :: HeaderCursor -> HeaderCursor
headerCursorStart = headerCursorTextCursorL %~ textCursorSelectStart

headerCursorEnd :: HeaderCursor -> HeaderCursor
headerCursorEnd = headerCursorTextCursorL %~ textCursorSelectEnd

data ContentsCursor = ContentsCursor
    { contentsCursorParent :: EntryCursor
    , contentsCursorContents :: TextFieldCursor
    }

instance Validity ContentsCursor where
    isValid a = isValid (build a) && isValid (rebuild a)
    validate a = (build a <?!> "build") <> (rebuild a <?!> "rebuild")

instance Show ContentsCursor where
    show ContentsCursor {..} =
        unlines ["[Entry]", " |-" ++ show contentsCursorContents]

instance Eq ContentsCursor where
    (==) = ((==) `on` build) &&& ((==) `on` rebuild)

instance Rebuild ContentsCursor where
    type ReBuilding ContentsCursor = SmosFile
    rebuild = rebuild . contentsCursorParent
    selection ContentsCursor {..} =
        selection contentsCursorContents ++
        [5] ++ selection contentsCursorParent

instance Build ContentsCursor where
    type Building ContentsCursor = Contents
    build ContentsCursor {..} = Contents $ rebuild contentsCursorContents

emptyContentsCursor :: EntryCursor -> ContentsCursor
emptyContentsCursor ec = contentsCursor ec $ Contents T.empty

contentsCursor :: EntryCursor -> Contents -> ContentsCursor
contentsCursor ec Contents {..} =
    ContentsCursor
    { contentsCursorParent = ec
    , contentsCursorContents = makeTextFieldCursor contentsText
    }

contentsCursorContentsL ::
       Functor f
    => (Contents -> f Contents)
    -> ContentsCursor
    -> f ContentsCursor
contentsCursorContentsL = lens getter setter
  where
    getter = build
    setter cc cs = cc'
      where
        ec' = contentsCursorParent cc & entryCursorContentsL .~ Just cc'
        cc' = contentsCursor ec' cs

contentsCursorSetContents :: Contents -> ContentsCursor -> ContentsCursor
contentsCursorSetContents cs = contentsCursorContentsL .~ cs

contentsCursorTextFieldL ::
       Functor f
    => (TextFieldCursor -> f TextFieldCursor)
    -> ContentsCursor
    -> f ContentsCursor
contentsCursorTextFieldL = lens getter setter
  where
    getter = contentsCursorContents
    setter cc tfc = cc'
      where
        ec' = contentsCursorParent cc & entryCursorContentsL .~ Just cc'
        cc' = cc {contentsCursorParent = ec', contentsCursorContents = tfc}

contentsCursorInsert :: Char -> ContentsCursor -> ContentsCursor
contentsCursorInsert c = contentsCursorTextFieldL %~ textFieldCursorInsert c

contentsCursorAppend :: Char -> ContentsCursor -> ContentsCursor
contentsCursorAppend c = contentsCursorTextFieldL %~ textFieldCursorAppend c

contentsCursorNewline :: ContentsCursor -> ContentsCursor
contentsCursorNewline = contentsCursorTextFieldL %~ textFieldCursorNewline

contentsCursorRemove :: ContentsCursor -> Maybe ContentsCursor
contentsCursorRemove = contentsCursorTextFieldL textFieldCursorRemove

contentsCursorDelete :: ContentsCursor -> Maybe ContentsCursor
contentsCursorDelete = contentsCursorTextFieldL textFieldCursorDelete

contentsCursorLeft :: ContentsCursor -> Maybe ContentsCursor
contentsCursorLeft = contentsCursorTextFieldL textFieldCursorSelectPrev

contentsCursorRight :: ContentsCursor -> Maybe ContentsCursor
contentsCursorRight = contentsCursorTextFieldL textFieldCursorSelectNext

contentsCursorUp :: ContentsCursor -> Maybe ContentsCursor
contentsCursorUp = contentsCursorTextFieldL textFieldCursorSelectUp

contentsCursorDown :: ContentsCursor -> Maybe ContentsCursor
contentsCursorDown = contentsCursorTextFieldL textFieldCursorSelectDown

contentsCursorStart :: ContentsCursor -> ContentsCursor
contentsCursorStart = contentsCursorTextFieldL %~ textFieldCursorSelectStart

contentsCursorEnd :: ContentsCursor -> ContentsCursor
contentsCursorEnd = contentsCursorTextFieldL %~ textFieldCursorSelectEnd

data StateCursor = StateCursor
    { stateCursorParent :: EntryCursor
    , stateCursorState :: Maybe TodoState
    }

instance Validity StateCursor where
    isValid a = isValid (build a) && isValid (rebuild a)
    validate a = (build a <?!> "build") <> (rebuild a <?!> "rebuild")

instance Show StateCursor where
    show StateCursor {..} = unlines ["[Entry]", " |-" ++ show stateCursorState]

instance Eq StateCursor where
    (==) = ((==) `on` build) &&& ((==) `on` rebuild)

instance Rebuild StateCursor where
    type ReBuilding StateCursor = SmosFile
    rebuild = rebuild . stateCursorParent
    selection StateCursor {..} = 0 : selection stateCursorParent

instance Build StateCursor where
    type Building StateCursor = Maybe TodoState
    build StateCursor {..} = stateCursorState

stateCursor :: EntryCursor -> Maybe TodoState -> StateCursor
stateCursor = StateCursor

stateCursorStateL ::
       Functor f
    => (Maybe TodoState -> f (Maybe TodoState))
    -> StateCursor
    -> f StateCursor
stateCursorStateL = lens getter setter
  where
    getter = stateCursorState
    setter sc ts = sc'
      where
        sc' =
            StateCursor
            { stateCursorParent =
                  stateCursorParent sc & entryCursorStateL .~ sc'
            , stateCursorState = ts
            }

stateCursorClear :: StateCursor -> StateCursor
stateCursorClear sc = sc & stateCursorStateL .~ Nothing

stateCursorSetState :: TodoState -> StateCursor -> StateCursor
stateCursorSetState ts sc = sc & stateCursorStateL .~ Just ts

(&&&) :: (a -> b -> Bool) -> (a -> b -> Bool) -> a -> b -> Bool
(&&&) op1 op2 a b = op1 a b && op2 a b

data TagsCursor = TagsCursor
    { tagsCursorParent :: EntryCursor
    , tagsCursorTags :: [TagCursor]
    }

instance Validity TagsCursor where
    isValid a = isValid (build a) && isValid (rebuild a)
    validate a = (build a <?!> "build") <> (rebuild a <?!> "rebuild")

instance Show TagsCursor where
    show TagsCursor {..} = unlines ["[Entry]", " |-" ++ show tagsCursorTags]

instance Eq TagsCursor where
    (==) = ((==) `on` build) &&& ((==) `on` rebuild)

instance Rebuild TagsCursor where
    type ReBuilding TagsCursor = SmosFile
    rebuild = rebuild . tagsCursorParent
    selection TagsCursor {..} = 2 : selection tagsCursorParent

instance Build TagsCursor where
    type Building TagsCursor = [Tag]
    build = map build . tagsCursorTags

tagsCursor :: EntryCursor -> [Tag] -> TagsCursor
tagsCursor ec tags = tsc
  where
    tsc = TagsCursor {tagsCursorParent = ec, tagsCursorTags = tagElems tsc tags}

tagElems :: TagsCursor -> [Tag] -> [TagCursor]
tagElems tsc sts = tcs
  where
    tcs = zipWith tc [0 ..] sts
    tc i t = cur
      where
        cur =
            TagCursor
            { tagCursorParent = tsc
            , tagCursorPrevElemens =
                  reverse $ filter ((< i) . tagCursorIndex) tcs
            , tagCursorNextElemens = filter ((> i) . tagCursorIndex) tcs
            , tagCursorIndex = i
            , tagCursorTag = makeTextCursor $ tagText t
            }

tagsCursorTagsL ::
       Functor f => ([TagCursor] -> f [TagCursor]) -> TagsCursor -> f TagsCursor
tagsCursorTagsL = lens getter setter
  where
    getter = tagsCursorTags
    setter cc ts = cc'
      where
        ec' = tagsCursorParent cc & entryCursorTagsL .~ cc'
        cc' = cc {tagsCursorParent = ec', tagsCursorTags = ts}

tagsCursorSelectFirst :: TagsCursor -> Maybe TagCursor
tagsCursorSelectFirst tsc =
    case tagsCursorTags tsc of
        [] -> Nothing
        (tc:_) -> Just tc

tagsCursorSelectLast :: TagsCursor -> Maybe TagCursor
tagsCursorSelectLast tsc =
    case reverse $ tagsCursorTags tsc of
        [] -> Nothing
        (tc:_) -> Just tc

tagsCursorInsertAt :: Int -> Tag -> TagsCursor -> TagsCursor
tagsCursorInsertAt ix_ newTag tsc = tsc'
  where
    tsc' =
        tsc & tagsCursorTagsL %~
        (\els ->
             tagElems tsc' $
             map build (prevs els) ++ [newTag] ++ map build (nexts els))
    ffilter rel = filter ((`rel` ix_) . tagCursorIndex)
    prevs = ffilter (<)
    nexts = ffilter (>=)

tagsCursorInsertAtStart :: Tag -> TagsCursor -> TagsCursor
tagsCursorInsertAtStart = tagsCursorInsertAt 0

tagsCursorAppendAtEnd :: Tag -> TagsCursor -> TagsCursor
tagsCursorAppendAtEnd t fc =
    tagsCursorInsertAt (length $ tagsCursorTags fc) t fc

data TagCursor = TagCursor
    { tagCursorParent :: TagsCursor
    , tagCursorPrevElemens :: [TagCursor]
    , tagCursorNextElemens :: [TagCursor]
    , tagCursorIndex :: Int
    , tagCursorTag :: TextCursor
    }

instance Validity TagCursor where
    isValid a = isValid (build a) && isValid (rebuild a)
    validate a = (build a <?!> "build") <> (rebuild a <?!> "rebuild")

instance Show TagCursor where
    show TagCursor {..} = unlines ["[Tags]", " |-" ++ show tagCursorTag]

instance Eq TagCursor where
    (==) = ((==) `on` build) &&& ((==) `on` rebuild)

instance Rebuild TagCursor where
    type ReBuilding TagCursor = SmosFile
    rebuild = rebuild . tagCursorParent
    selection TagCursor {..} =
        selection tagCursorTag ++
        [length tagCursorPrevElemens] ++ selection tagCursorParent

instance Build TagCursor where
    type Building TagCursor = Tag
    build TagCursor {..} = Tag $ rebuild tagCursorTag

tagCursorTextCursorL ::
       Functor f => (TextCursor -> f TextCursor) -> TagCursor -> f TagCursor
tagCursorTextCursorL = lens getter setter
  where
    getter = tagCursorTag
    setter tc textC = tagCursorModify (const textC) tc

tagCursorModify :: (TextCursor -> TextCursor) -> TagCursor -> TagCursor
tagCursorModify tfunc tc = tc''
  where
    tc' = tc {tagCursorTag = tfunc $ tagCursorTag tc}
    tcs = reverse (tagCursorPrevElemens tc) ++ [tc'] ++ tagCursorNextElemens tc
    tags = map build tcs
    fc = tagCursorParent tc & tagsCursorTagsL .~ els
    els = tagElems fc tags
    tc'' = els !! tagCursorIndex tc

tagCursorInsert :: Char -> TagCursor -> TagCursor
tagCursorInsert c = tagCursorTextCursorL %~ textCursorInsert c

tagCursorAppend :: Char -> TagCursor -> TagCursor
tagCursorAppend c = tagCursorTextCursorL %~ textCursorAppend c

tagCursorRemove :: TagCursor -> Maybe TagCursor
tagCursorRemove = tagCursorTextCursorL textCursorRemove

tagCursorDelete :: TagCursor -> Maybe TagCursor
tagCursorDelete = tagCursorTextCursorL textCursorDelete

tagCursorLeft :: TagCursor -> Maybe TagCursor
tagCursorLeft = tagCursorTextCursorL textCursorSelectPrev

tagCursorRight :: TagCursor -> Maybe TagCursor
tagCursorRight = tagCursorTextCursorL textCursorSelectNext

tagCursorStart :: TagCursor -> TagCursor
tagCursorStart = tagCursorTextCursorL %~ textCursorSelectStart

tagCursorEnd :: TagCursor -> TagCursor
tagCursorEnd = tagCursorTextCursorL %~ textCursorSelectEnd

tagCursorSelectPrev :: TagCursor -> Maybe TagCursor
tagCursorSelectPrev tc =
    case tagCursorNextElemens tc of
        [] -> Nothing
        (tc':_) -> Just tc'

tagCursorSelectNext :: TagCursor -> Maybe TagCursor
tagCursorSelectNext tc =
    case tagCursorNextElemens tc of
        [] -> Nothing
        (tc':_) -> Just tc'

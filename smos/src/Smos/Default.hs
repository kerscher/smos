{-# LANGUAGE OverloadedStrings #-}

module Smos.Default where

import Import

import Smos
import Smos.Actions
import Smos.Keys
import Smos.Style

defaultSmos :: IO ()
defaultSmos = smos defaultConfig

defaultConfig :: SmosConfig
defaultConfig =
    SmosConfig
    { configKeyMap =
          mconcat
              [ inEmpty $
                mconcat
                    [ matchChar 'h' $ insertTreeBelow >> enterHeader
                    , matchChar 'q' stop
                    , matchKey KEsc stop
                    ]
              , inEntry $
                mconcat
                    [ matchChar 'h' $ insertTreeBelow >> enterHeader
                    , matchChar 'H' $ insertTreeChild >> enterHeader
                    , matchChar 'd' deleteCurrentHeader
                    , matchChar 'i' $ enterHeader >> headerStart
                    , matchChar 'a' $ enterHeader >> headerEnd
                    , matchChar 'e' $ enterContents >> contentsStart
                    , matchChar 't' enterTodoState
                    , matchChar 'g' enterTag
                    , matchChar 'c' clockIn
                    , matchChar 'o' clockOut
                    , matchChar 'j' moveDown
                    , matchChar 'k' moveUp
                    , matchChar 'h' moveLeft
                    , matchChar 'l' moveRight
                    , matchKey KDown moveDown
                    , matchKey KUp moveUp
                    , matchKey KLeft moveLeft
                    , matchKey KRight moveRight
                    , matchChar 'v' $ commandOnContentsFile "urxvt -e vim"
                    , matchChar 's' save
                    , matchChar 'q' stop
                    , matchKey KEsc stop
                    ]
              , inHeader $
                mconcat
                    [ onChar headerInsert
                    , matchKey KBS headerRemove
                    , matchKey KDel headerDelete
                    , matchKey KLeft headerLeft
                    , matchKey KRight headerRight
                    , matchKey KEnter exitHeader
                    , matchKey KEsc exitHeader
                    ]
              , inContents $
                mconcat
                    [ onChar contentsInsert
                    , matchKey KBS contentsRemove
                    , matchKey KDel contentsDelete
                    , matchKey KLeft contentsLeft
                    , matchKey KRight contentsRight
                    , matchKey KUp contentsUp
                    , matchKey KDown contentsDown
                    , matchKey KEnter contentsNewline
                    , matchKey KEsc exitContents
                    ]
              , inTodoState $
                mconcat
                    [ matchChar ' ' todoStateClear
                    , matchChar 't' $ todoStateSet "TODO" >> exitTodoState
                    , matchChar 'n' $ todoStateSet "NEXT" >> exitTodoState
                    , matchChar 's' $ todoStateSet "STARTED" >> exitTodoState
                    , matchChar 'r' $ todoStateSet "READY" >> exitTodoState
                    , matchChar 'w' $ todoStateSet "WAITING" >> exitTodoState
                    , matchChar 'd' $ todoStateSet "DONE" >> exitTodoState
                    , matchChar 'c' $ todoStateSet "CANCELLED" >> exitTodoState
                    ]
              , inTag $
                mconcat
                    [ onChar tagInsert
                    , matchKey KBS tagRemove
                    , matchKey KDel tagDelete
                    , matchKey KLeft tagLeft
                    , matchKey KRight tagRight
                    , matchKey KBackTab tagSelectNext
                    , matchKey KEnter exitTag
                    , matchKey KEsc exitTag
                    ]
              ]
    , configAttrMap =
          let col = rgbColor :: Int -> Int -> Int -> Color
              orange = col 255 165 0
              brown = col 205 133 63
          in applyAttrMappings
                 [ (todoStateSpecificAttr "TODO", fg red)
                 , (todoStateSpecificAttr "NEXT", fg orange)
                 , (todoStateSpecificAttr "STARTED", fg orange)
                 , (todoStateSpecificAttr "WAITING", fg blue)
                 , (todoStateSpecificAttr "READY", fg brown)
                 , (todoStateSpecificAttr "DONE", fg green)
                 , (todoStateSpecificAttr "CANCELLED", fg green)
                 , (selectedAttr <> tagAttr, fg brightWhite)
                 ] .
             defaultAttrMap
    , configAgendaFiles =
          do home <- getHomeDir
             d <- resolveDir home "smos"
             fromMaybe [] <$> forgivingAbsence (snd <$> listDirRecur d)
    }

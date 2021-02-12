module Stream exposing
    ( updateCurrentNameL
    , updateCurrentNameR
    , updateCurrentWinsL
    , updateCurrentWinsR
    , updateStateWithMessage
    )

import Array
import Types exposing (Message(..), StreamState)


updateStateWithMessage : StreamState -> Message -> StreamState
updateStateWithMessage ss msg =
    case msg of
        NewGame payload ->
            -- @TODO: determine if new set here
            { ss
                | players = Array.fromList payload.players
                , currentPcts = Array.repeat (List.length payload.players) 0
            }

        EndGame payload ->
            { ss
                | endGames = payload :: ss.endGames
            }

        PercentChange payload ->
            { ss
                | currentPcts = Array.set payload.playerIndex payload.percent ss.currentPcts
            }

        StockChange payload ->
            let
                mTargetPlayer =
                    Array.get payload.playerIndex ss.players
            in
            case mTargetPlayer of
                Nothing ->
                    ss

                Just player ->
                    { ss
                        | players = Array.set payload.playerIndex { player | startStocks = Just payload.stocksRemaining } ss.players
                    }

        CharacterChange payload ->
            { ss | currentChars = Array.fromList payload.characters }


updateCurrentWinsL :
    StreamState
    -> (Int -> Int)
    -> StreamState
updateCurrentWinsL ss f =
    { ss | currentWinsL = f ss.currentWinsL }


updateCurrentWinsR :
    StreamState
    -> (Int -> Int)
    -> StreamState
updateCurrentWinsR ss f =
    { ss | currentWinsR = f ss.currentWinsR }


updateCurrentNameL :
    StreamState
    -> String
    -> StreamState
updateCurrentNameL ss string =
    { ss | currentNameL = string }


updateCurrentNameR :
    StreamState
    -> String
    -> StreamState
updateCurrentNameR ss string =
    { ss | currentNameR = string }

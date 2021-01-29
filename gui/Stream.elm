module Stream exposing (updateStateWithMessage)

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

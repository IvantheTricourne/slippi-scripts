module Types exposing
    ( CellValue(..)
    , Character
    , CharacterChangePayload
    , EndGamePayload
    , FavoriteMove
    , Game
    , Message(..)
    , MessageRecord
    , NewGamePayload
    , PercentChangePayload
    , Player
    , PlayerStat
    , PlayerType
    , Stats
    , StatsConfig
    , StatsConfigField(..)
    , StatsResponse
    , StockChangePayload
    , StreamState
    )

import Array exposing (Array)
import Json.Decode exposing (Value)


type alias StreamState =
    { players : Array PlayerType
    , endGames : List EndGamePayload
    , currentPcts : Array Float
    , currentChars : Array Character
    , currentWinsL : Int
    , currentWinsR : Int
    , currentNameL : String
    , currentNameR : String
    }


type alias MessageRecord =
    { msgRecType : String
    , msgRecPayload : Value
    }


type Message
    = NewGame NewGamePayload
    | EndGame EndGamePayload
    | PercentChange PercentChangePayload
    | StockChange StockChangePayload
    | CharacterChange CharacterChangePayload


type alias NewGamePayload =
    { slpVersion : Maybe String
    , isTeams : Maybe Bool
    , isPAL : Maybe Bool
    , stageId : Maybe Int
    , players : List PlayerType
    }


type alias PlayerType =
    { playerIndex : Int
    , playerPort : Int
    , characterId : Maybe Int
    , characterColor : Maybe Int
    , startStocks : Maybe Int
    , playerType : Maybe Int
    , teamId : Maybe Int
    , controllerFix : Maybe String
    , nametag : Maybe String
    }


type alias EndGamePayload =
    { gameEndMethod : Maybe Int
    , lrasInitiatorIndex : Maybe Int
    , winnerPlayerIndex : Int
    }


type alias PercentChangePayload =
    { playerIndex : Int
    , percent : Float
    }


type alias StockChangePayload =
    { playerIndex : Int
    , stocksRemaining : Int
    }


type alias CharacterChangePayload =
    { characters : List Character
    }


type StatsConfigField
    = TotalDamageF
    | NeutralWinsF
    | CounterHitsF
    | AvgApmF
    | AvgOpeningsPerKillF
    | AvgDamagePerOpeningF
    | AvgKillPercentF
    | FavoriteMoveF
    | FavoriteKillMoveF
    | SetCountAndWinnerF
    | StagesF


type alias StatsConfig =
    { totalDamage : Bool
    , neutralWins : Bool
    , counterHits : Bool
    , avgApm : Bool
    , avgOpeningsPerKill : Bool
    , avgDamagePerOpening : Bool
    , avgKillPercent : Bool
    , favoriteMove : Bool
    , favoriteKillMove : Bool
    , setCountAndWinner : Bool
    , stages : Bool
    }


type alias StatsResponse =
    { totalGames : Int
    , stats : Value
    }


type alias Stats =
    { games : Array Game
    , totalLengthSeconds : Float
    , players : Array Player
    , playerStats : Array PlayerStat
    , sagaIcon : String
    }


type alias Game =
    { stage : String
    , winner : Player
    , stocks : Int
    , players : Array Player
    , length : String
    }


type alias Character =
    { characterName : String
    , color : String
    }


type alias Player =
    { playerPort : Int
    , tag : String
    , netplayName : String
    , rollbackCode : String
    , character : Character
    , characters : Array Character
    , idx : Int
    }


type alias PlayerStat =
    { totalDamage : Float
    , neutralWins : Int
    , counterHits : Int
    , avgApm : Float
    , avgOpeningsPerKill : Float
    , avgDamagePerOpening : Float
    , avgKillPercent : Float
    , favoriteMove : FavoriteMove
    , favoriteKillMove : FavoriteMove
    , wins : Int
    }


type alias FavoriteMove =
    { moveName : String
    , timesUsed : Int
    }



-- Stat Cell Type
-- i.e., single value or value with sub


type CellValue
    = Single (StatsConfig -> Bool) String
    | Dub (StatsConfig -> Bool) String String

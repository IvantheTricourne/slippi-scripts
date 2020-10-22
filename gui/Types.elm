module Types exposing
    ( CellValue(..)
    , Character
    , Combo
    , FavoriteMove
    , Game
    , Player
    , PlayerStat
    , Stats
    , StatsConfig
    , StatsConfigField(..)
    , StatsResponse
    )

import Array exposing (Array)
import Json.Decode exposing (Value)


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
    , shortestStock : Maybe Float
    , longestStock : Maybe Float
    , earliestKill : Maybe Float
    , latestKill : Maybe Float
    , longestCombo : Combo
    }


type alias FavoriteMove =
    { moveName : String
    , timesUsed : Int
    }


type alias Combo =
    { damage : Float
    , moveCount : Int
    }



-- Stat Cell Type
-- i.e., single value or value with sub


type CellValue
    = Single (StatsConfig -> Bool) String
    | Dub (StatsConfig -> Bool) String String

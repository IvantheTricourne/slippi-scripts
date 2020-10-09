module Types exposing
    ( CellValue(..)
    , Character
    , FavoriteMove
    , Game
    , Player
    , PlayerStat
    , Stats
    )

import Array exposing (Array)


type alias Stats =
    { totalGames : Int
    , games : Array Game
    , totalLengthSeconds : Float
    , players : Array Player
    , playerStats : Array PlayerStat
    , sagaIcon : String
    }


type alias Game =
    { stage : String
    , winner : Player
    , players : Array Player
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
    , favoriteMove : FavoriteMove
    , favoriteKillMove : FavoriteMove
    }


type alias FavoriteMove =
    { moveName : String
    , timesUsed : Int
    }



-- Stat Cell Type
-- i.e., single value or value with sub


type CellValue
    = Single String
    | Dub ( String, String )

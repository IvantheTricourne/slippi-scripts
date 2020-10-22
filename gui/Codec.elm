module Codec exposing
    ( characterDecoder
    , characterEncoder
    , favoriteMoveDecoder
    , favoriteMoveEncoder
    , gameDecoder
    , gameEncoder
    , playerDecoder
    , playerEncoder
    , playerStatDecoder
    , playerStatEncoder
    , statsConfigDecoder
    , statsConfigEncoder
    , statsDecoder
    , statsEncoder
    , statsResponseDecoder
    )

import Json.Decode as D
import Json.Decode.Extra as D
import Json.Encode as E
import Json.Encode.Extra as E
import Types exposing (..)



-- encoders


statsConfigEncoder : StatsConfig -> E.Value
statsConfigEncoder statsCfg =
    E.object
        [ ( "totalDamage", E.bool statsCfg.totalDamage )
        , ( "neutralWins", E.bool statsCfg.neutralWins )
        , ( "counterHits", E.bool statsCfg.counterHits )
        , ( "avgApm", E.bool statsCfg.avgApm )
        , ( "avgOpeningsPerKill", E.bool statsCfg.avgOpeningsPerKill )
        , ( "avgDamagePerOpening", E.bool statsCfg.avgDamagePerOpening )
        , ( "avgKillPercent", E.bool statsCfg.avgKillPercent )
        , ( "favoriteMove", E.bool statsCfg.favoriteMove )
        , ( "favoriteKillMove", E.bool statsCfg.favoriteKillMove )
        , ( "setCountAndWinner", E.bool statsCfg.setCountAndWinner )
        , ( "stages", E.bool statsCfg.stages )
        ]


statsEncoder : Stats -> E.Value
statsEncoder stats =
    E.object
        [ ( "games", E.array gameEncoder stats.games )
        , ( "totalLengthSeconds", E.float stats.totalLengthSeconds )
        , ( "players", E.array playerEncoder stats.players )
        , ( "playerStats", E.array playerStatEncoder stats.playerStats )
        , ( "sagaIcon", E.string stats.sagaIcon )
        ]


gameEncoder : Game -> E.Value
gameEncoder game =
    E.object
        [ ( "stage", E.string game.stage )
        , ( "winner", playerEncoder game.winner )
        , ( "stocks", E.int game.stocks )
        , ( "players", E.array playerEncoder game.players )
        , ( "length", E.string game.length )
        ]


characterEncoder : Character -> E.Value
characterEncoder character =
    E.object
        [ ( "characterName", E.string character.characterName )
        , ( "color", E.string character.color )
        ]


playerEncoder : Player -> E.Value
playerEncoder player =
    E.object
        [ ( "port", E.int player.playerPort )
        , ( "tag", E.string player.tag )
        , ( "netplayName", E.string player.netplayName )
        , ( "rollbackCode", E.string player.rollbackCode )
        , ( "character", characterEncoder player.character )
        , ( "characters", E.array characterEncoder player.characters )
        , ( "idx", E.int player.idx )
        ]


playerStatEncoder : PlayerStat -> E.Value
playerStatEncoder playerStat =
    E.object
        [ ( "totalDamage", E.float playerStat.totalDamage )
        , ( "neutralWins", E.int playerStat.neutralWins )
        , ( "counterHits", E.int playerStat.counterHits )
        , ( "avgApm", E.float playerStat.avgApm )
        , ( "avgOpeningsPerKill", E.float playerStat.avgOpeningsPerKill )
        , ( "avgDamagePerOpening", E.float playerStat.avgDamagePerOpening )
        , ( "avgKillPercent", E.float playerStat.avgKillPercent )
        , ( "favoriteMove", favoriteMoveEncoder playerStat.favoriteMove )
        , ( "favoriteKillMove", favoriteMoveEncoder playerStat.favoriteKillMove )
        , ( "wins", E.int playerStat.wins )
        , ( "shortestStock", E.maybe E.float playerStat.shortestStock )
        , ( "longestStock", E.maybe E.float playerStat.longestStock )
        , ( "earliestKill", E.maybe E.float playerStat.earliestKill )
        , ( "latestKill", E.maybe E.float playerStat.latestKill )
        , ( "longestCombo", comboEncoder playerStat.longestCombo )
        ]


favoriteMoveEncoder : FavoriteMove -> E.Value
favoriteMoveEncoder favMov =
    E.object
        [ ( "moveName", E.string favMov.moveName )
        , ( "timesUsed", E.int favMov.timesUsed )
        ]


comboEncoder : Combo -> E.Value
comboEncoder combo =
    E.object
        [ ( "damage", E.float combo.damage )
        , ( "moveCount", E.int combo.moveCount )
        ]



-- decoders


statsResponseDecoder : D.Decoder StatsResponse
statsResponseDecoder =
    D.map2 StatsResponse
        (D.field "totalGames" D.int)
        (D.field "stats" D.value)


statsConfigDecoder : D.Decoder StatsConfig
statsConfigDecoder =
    D.succeed StatsConfig
        |> D.andMap (D.field "totalDamage" D.bool)
        |> D.andMap (D.field "neutralWins" D.bool)
        |> D.andMap (D.field "counterHits" D.bool)
        |> D.andMap (D.field "avgApm" D.bool)
        |> D.andMap (D.field "avgOpeningsPerKill" D.bool)
        |> D.andMap (D.field "avgDamagePerOpening" D.bool)
        |> D.andMap (D.field "avgKillPercent" D.bool)
        |> D.andMap (D.field "favoriteMove" D.bool)
        |> D.andMap (D.field "favoriteKillMove" D.bool)
        |> D.andMap (D.field "shortestStock" D.bool)
        |> D.andMap (D.field "longestStock" D.bool)
        |> D.andMap (D.field "earliestKill" D.bool)
        |> D.andMap (D.field "latestKill" D.bool)
        |> D.andMap (D.field "longestCombo" D.bool)
        |> D.andMap (D.field "setCountAndWinner" D.bool)
        |> D.andMap (D.field "stages" D.bool)


statsDecoder : D.Decoder Stats
statsDecoder =
    D.map5 Stats
        (D.field "games" <| D.array gameDecoder)
        (D.field "totalLengthSeconds" D.float)
        (D.field "players" <| D.array playerDecoder)
        (D.field "playerStats" <| D.array playerStatDecoder)
        (D.field "sagaIcon" <| D.string)


gameDecoder : D.Decoder Game
gameDecoder =
    D.map5 Game
        (D.field "stage" D.string)
        (D.field "winner" playerDecoder)
        (D.field "stocks" D.int)
        (D.field "players" <| D.array playerDecoder)
        (D.field "length" D.string)


characterDecoder : D.Decoder Character
characterDecoder =
    D.map2 Character
        (D.field "characterName" D.string)
        (D.field "color" D.string)


playerDecoder : D.Decoder Player
playerDecoder =
    D.map7 Player
        (D.field "port" D.int)
        (D.field "tag" D.string)
        (D.field "netplayName" D.string)
        (D.field "rollbackCode" D.string)
        (D.field "character" characterDecoder)
        (D.field "characters" <| D.array characterDecoder)
        (D.field "idx" D.int)


playerStatDecoder : D.Decoder PlayerStat
playerStatDecoder =
    D.succeed PlayerStat
        |> D.andMap (D.field "totalDamage" D.float)
        |> D.andMap (D.field "neutralWins" D.int)
        |> D.andMap (D.field "counterHits" D.int)
        |> D.andMap (D.field "avgApm" D.float)
        |> D.andMap (D.field "avgOpeningsPerKill" D.float)
        |> D.andMap (D.field "avgDamagePerOpening" D.float)
        |> D.andMap (D.field "avgKillPercent" D.float)
        |> D.andMap (D.field "favoriteMove" favoriteMoveDecoder)
        |> D.andMap (D.field "favoriteKillMove" favoriteMoveDecoder)
        |> D.andMap (D.field "wins" D.int)
        |> D.andMap (D.field "shortestStock" <| D.nullable D.float)
        |> D.andMap (D.field "longestStock" <| D.nullable D.float)
        |> D.andMap (D.field "earliestKill" <| D.nullable D.float)
        |> D.andMap (D.field "latestKill" <| D.nullable D.float)
        |> D.andMap (D.field "longestCombo" comboDecoder)


favoriteMoveDecoder : D.Decoder FavoriteMove
favoriteMoveDecoder =
    D.map2 FavoriteMove
        (D.field "moveName" D.string)
        (D.field "timesUsed" D.int)


comboDecoder : D.Decoder Combo
comboDecoder =
    D.map2 Combo
        (D.field "damage" D.float)
        (D.field "moveCount" D.int)

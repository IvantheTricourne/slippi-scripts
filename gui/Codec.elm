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
    )

import Json.Decode as D
import Json.Encode as E
import Types exposing (..)



-- encoders


gameEncoder : Game -> E.Value
gameEncoder game =
    E.object
        [ ( "stage", E.string game.stage )
        , ( "winner", playerEncoder game.winner )
        , ( "players", E.array playerEncoder game.players )
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


playerStatAvgsEncoder : PlayerStatAvgs -> E.Value
playerStatAvgsEncoder playerStatAvgs =
    E.object
        [ ( "avgApm", E.float playerStatAvgs.avgApm )
        , ( "avgOpeningsPerKill", E.float playerStatAvgs.avgOpeningsPerKill )
        , ( "avgDamagePerOpening", E.float playerStatAvgs.avgDamagePerOpening )
        ]


playerStatEncoder : PlayerStat -> E.Value
playerStatEncoder playerStat =
    E.object
        [ ( "totalDamage", E.float playerStat.totalDamage )
        , ( "neutralWins", E.int playerStat.neutralWins )
        , ( "counterHits", E.int playerStat.counterHits )
        , ( "avgs", playerStatAvgsEncoder playerStat.avgs )
        , ( "favoriteMove", favoriteMoveEncoder playerStat.favoriteMove )
        , ( "favoriteKillMove", favoriteMoveEncoder playerStat.favoriteKillMove )
        , ( "wins", E.int playerStat.wins )
        ]


favoriteMoveEncoder : FavoriteMove -> E.Value
favoriteMoveEncoder favMov =
    E.object
        [ ( "moveName", E.string favMov.moveName )
        , ( "timesUsed", E.int favMov.timesUsed )
        ]



-- decoders


gameDecoder : D.Decoder Game
gameDecoder =
    D.map3 Game
        (D.field "stage" D.string)
        (D.field "winner" playerDecoder)
        (D.field "players" <| D.array playerDecoder)


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


playerStatAvgsDecoder : D.Decoder PlayerStatAvgs
playerStatAvgsDecoder =
    D.map3 PlayerStatAvgs
        (D.field "avgApm" D.float)
        (D.field "avgOpeningsPerKill" D.float)
        (D.field "avgDamagePerOpening" D.float)


playerStatDecoder : D.Decoder PlayerStat
playerStatDecoder =
    D.map7 PlayerStat
        (D.field "totalDamage" D.float)
        (D.field "neutralWins" D.int)
        (D.field "counterHits" D.int)
        (D.field "avgs" playerStatAvgsDecoder)
        (D.field "favoriteMove" favoriteMoveDecoder)
        (D.field "favoriteKillMove" favoriteMoveDecoder)
        (D.field "wins" D.int)


favoriteMoveDecoder : D.Decoder FavoriteMove
favoriteMoveDecoder =
    D.map2 FavoriteMove
        (D.field "moveName" D.string)
        (D.field "timesUsed" D.int)

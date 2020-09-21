port module Main exposing (..)

import Array exposing (..)
import Browser
import Bytes exposing (Bytes)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import File as File exposing (File)
import File.Select as Select
import Html exposing (Html)
import Json.Decode as D
import Json.Encode as E
import Maybe
import Task

-- model

type alias Model = Maybe Stats
type alias Stats =
    { totalGames : Int
    , stages : Array String
    , totalLengthSeconds : Float
    , players : Array Player
    , playerStats : Array PlayerStat
    , sagaIcon : String
    }
type alias Player =
    { playerPort : Int
    , tag : String
    , netplayName : String
    , rollbackCode : String
    , characterName : String
    , color : String
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
    }
type alias FavoriteMove =
    { moveName : String
    , timesUsed : Int
    }

-- update

type Msg
    = Reset
    | JsonRequested
    | JsonSelected File
    | JsonLoaded String

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Reset ->
            ( Nothing
            , Cmd.none
            )
        JsonRequested ->
            ( model
            , Select.file [ "application/json" ] JsonSelected
            )
        JsonSelected file ->
            ( model
            , Task.perform JsonLoaded (File.toString file)
            )
        JsonLoaded str ->
            ( case D.decodeString statsDecoder str of
                  Ok stats -> Just stats
                  Err _ -> Nothing
            , Cmd.none
            )

-- view
-- @TODO: clean up styles
view : Model -> Html Msg
view model =
    Element.layout [ Background.color black
                   , Font.family [ Font.external
                                       { name = "Roboto"
                                       , url = "https://fonts.googleapis.com/css?family=Roboto"
                                       }
                                 , Font.monospace
                                 ]
                   ] <|
    column [ centerX
           , centerY
           , spacing 10
           ]
    (case model of
         Nothing -> viewInit
         Just stats -> viewStats stats)

viewStats stats =
    let player0 = Maybe.withDefault defaultPlayer <| get 0 stats.players
        player1 = Maybe.withDefault defaultPlayer <| get 1 stats.players
    in
    [ renderStageImgs << toList <| stats.stages
    , row [ centerX
          ]
        [ renderStatColumn [ Font.color white
                           , Font.alignRight
                           , Font.extraBold
                           , spacing 15
                           ]
              [ renderPlayerName player0 ]
        , renderStatColumn [ Font.color white
                           , Font.center
                           , Font.bold
                           , Font.italic
                           , spacing 15
                           ]
            [ "vs." ]
        , renderStatColumn [ Font.color white
                           , Font.alignLeft
                           , Font.extraBold
                           , spacing 15
                           ]
              [ renderPlayerName player1 ]
        ]
    , row [ centerX
          , spacing 10
          , padding 15
          ]
        [ renderStatColumn [ Font.color white
                           , Font.alignRight
                           , Background.uncropped <| playerCharImgPath player0

                           , spacing 15
                           ]
              (listifyPlayerStat <| get 0 stats.playerStats)
        , renderStatColumn [ Font.color white
                           , Font.center
                           , Font.bold
                           , Font.italic
                           , spacing 15
                           ]
            [ "Total Damage"
            , "APM"
            , "Openings / Kill"
            , "Damage / Opening"
            , "Neutral Wins"
            , "Counter Hits"
            , "Favorite Move"
            ]
        , renderStatColumn [ Font.color white
                           , Font.alignLeft
                           , Background.uncropped <| playerCharImgPath player1
                           , spacing 15
                           ]
            (listifyPlayerStat <| get 1 stats.playerStats)
        ]
    , image [ centerX
            , Element.mouseOver [ Background.color red
                                ]
            , padding 2
            , Border.rounded 5
            , Events.onClick Reset
            ]
        -- @TODO: maybe make this the winner's Saga Icon?
        { src = "rsrc/Characters/Saga Icons/" ++ stats.sagaIcon ++ ".png"
        , description = "Logo for set winner"
        }
    ]
viewInit =
    [ image [ centerX
            , Element.mouseOver [ Background.color red
                                ]
            , padding 2
            , Border.rounded 5
            , Events.onClick JsonRequested
            ]
          -- @TODO: maybe make this the winner's Saga Icon?
          { src = "rsrc/Characters/Saga Icons/Smash.png"
          , description = "Logo for set winner"
          }
    ]

listifyPlayerStat : Maybe PlayerStat -> List String
listifyPlayerStat mStat =
    case mStat of
        Nothing -> []
        Just stat ->
            [ String.fromInt << round <| stat.totalDamage
            , String.fromInt << round <| stat.avgApm
            , String.fromInt << round <| stat.avgOpeningsPerKill
            , String.fromInt << round <| stat.avgDamagePerOpening
            , String.fromInt stat.neutralWins
            , String.fromInt stat.counterHits
            , let moveName = stat.favoriteMove.moveName
                  timesUsed = stat.favoriteMove.timesUsed
              in moveName ++ " (" ++ String.fromInt timesUsed ++ ")"
            ]

renderStageImgs stages =
    row [ centerX
        , spacing 10
        ] <|
        List.indexedMap
            (\i stageName -> image [ Background.color white
                                   , Border.rounded 3
                                   , padding 1
                                   ]
                 { src = stageImgPath stageName
                 , description = "Stage for game " ++ String.fromInt i
                 })
            stages

renderStatColumn styles strings =
    Element.indexedTable styles
        { data = strings
        , columns =
              [ { header = text ""
                , width = px 230
                , view = \_ x -> text x
                }
              ]
        }

renderPlayerName player =
    case player.rollbackCode of
        "n/a" -> case player.netplayName of
                     "No Name" -> player.characterName
                     _ -> player.netplayName
        _ -> player.netplayName ++ " / " ++ player.rollbackCode

playerCharImgPath : Player -> String
playerCharImgPath player =
    "rsrc/Characters/Portraits/" ++ player.characterName ++ "/" ++ player.color ++ ".png"

stageImgPath : String -> String
stageImgPath stageName =
    "rsrc/Stages/Icons/" ++ stageName ++ ".png"

-- elements
black = rgb255 0 0 0
white = rgb255 255 255 255
grey = rgb255 25 25 25
red = rgb255 255 0 0

-- ports

port setStorage : E.Value -> Cmd msg

updateWithStorage : Msg -> Model -> ( Model, Cmd Msg )
updateWithStorage msg oldModel =
  let
    ( newModel, cmds ) = update msg oldModel
    eModel = encode newModel
  in
  ( newModel
  , Cmd.batch [ setStorage eModel
              , cmds
              ]
  )

-- codecs

encode : Model -> E.Value
encode model =
    case model of
        Nothing -> E.object []
        Just stats ->
            E.object
                [ ("totalGames", E.int stats.totalGames)
                , ("stages", E.array E.string stats.stages)
                , ("totalLengthSeconds", E.float stats.totalLengthSeconds)
                , ("players", E.array playerEncoder stats.players)
                , ("playerStats", E.array playerStatEncoder stats.playerStats)
                , ("sagaIcon" , E.string stats.sagaIcon)
                ]

playerEncoder : Player -> E.Value
playerEncoder player =
    E.object
        [ ("port", E.int player.playerPort)
        , ("tag", E.string player.tag)
        , ("netplayName", E.string player.netplayName)
        , ("rollbackCode", E.string player.rollbackCode)
        , ("characterName", E.string player.characterName)
        , ("color", E.string player.color)
        , ("idx", E.int player.idx)
        ]

playerStatEncoder : PlayerStat -> E.Value
playerStatEncoder playerStat =
    E.object
        [ ("totalDamage", E.float playerStat.totalDamage)
        , ("neutralWins", E.int playerStat.neutralWins)
        , ("counterHits", E.int playerStat.counterHits)
        , ("avgApm", E.float playerStat.avgApm)
        , ("avgOpeningsPerKill", E.float playerStat.avgOpeningsPerKill)
        , ("avgDamagePerOpening", E.float playerStat.avgDamagePerOpening)
        , ("favoriteMove", favoriteMoveEncoder playerStat.favoriteMove)
        ]

favoriteMoveEncoder : FavoriteMove -> E.Value
favoriteMoveEncoder favMov =
    E.object
        [ ("moveName", E.string favMov.moveName)
        , ("timesUsed", E.int favMov.timesUsed)
        ]

decoder : D.Decoder Model
decoder = D.nullable statsDecoder

statsDecoder : D.Decoder Stats
statsDecoder =
  D.map6 Stats
    (D.field "totalGames" D.int)
    (D.field "stages" <| D.array D.string)
    (D.field "totalLengthSeconds" D.float)
    (D.field "players" <| D.array playerDecoder)
    (D.field "playerStats" <| D.array playerStatDecoder)
    (D.field "sagaIcon" <| D.string)


playerDecoder : D.Decoder Player
playerDecoder =
    D.map7 Player
        (D.field "port" D.int)
        (D.field "tag" D.string)
        (D.field "netplayName" D.string)
        (D.field "rollbackCode" D.string)
        (D.field "characterName" D.string)
        (D.field "color" D.string)
        (D.field "idx" D.int)

-- default player for handling maybes
defaultPlayer : Player
defaultPlayer =
    { playerPort = 0
    , tag = "XXXX"
    , netplayName = "n/a"
    , rollbackCode = "XXXX#YYYYY"
    , characterName = "Sonic"
    , color = "Emerald"
    , idx = 5
    }

playerStatDecoder : D.Decoder PlayerStat
playerStatDecoder =
    D.map7 PlayerStat
        (D.field "totalDamage" D.float)
        (D.field "neutralWins" D.int)
        (D.field "counterHits" D.int)
        (D.field "avgApm" D.float)
        (D.field "avgOpeningsPerKill" D.float)
        (D.field "avgDamagePerOpening" D.float)
        (D.field "favoriteMove" favoriteMoveDecoder)

favoriteMoveDecoder : D.Decoder FavoriteMove
favoriteMoveDecoder =
    D.map2 FavoriteMove
        (D.field "moveName" D.string)
        (D.field "timesUsed" D.int)

-- subscriptions
subscriptions : Model -> Sub Msg
subscriptions _ = Sub.none

-- main

init : E.Value -> ( Model, Cmd Msg )
init flags =
    ( case D.decodeValue decoder flags of
          Ok model -> model
          Err _ -> Nothing
    , Cmd.none
    )

main = Browser.element
       { init = init
       , update = updateWithStorage
       , view = view
       , subscriptions = subscriptions
       }

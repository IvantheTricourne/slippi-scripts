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
    }

-- update

type Msg
    = Go
    | Reset
    | JsonRequested
    | JsonSelected File
    | JsonLoaded String

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Go ->
            ( model
            , Cmd.none
            )
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
view : Model -> Html Msg
view model =
    Element.layout [ Background.color black
                   ] <|
    column [ centerX
           , centerY
           , spacing 10
           ]
    [ textColumn [ Font.color white
                 , Font.center
                 , spacing 5
                 ]
          (case model of
              Nothing -> [ text "Upload a JSON file" ]
              Just stats -> [ let player0 = Maybe.withDefault defaultPlayer <| get 0 stats.players
                                  player1 = Maybe.withDefault defaultPlayer <| get 1 stats.players
                              in paragraph [ Font.bold ]
                                  [ text <| player0.rollbackCode ++ " vs. " ++ player1.rollbackCode ]
                            , paragraph [ Font.italic ]
                                [ text <| String.fromInt stats.totalGames ++ " games found" ]
                            , paragraph []
                                [ text <| String.join ", " (toList stats.stages)]
                            ])
    , row [ centerX
          , spacing 10
          ]
        (case model of
            Nothing -> [ btnElement "upload" JsonRequested
                       ]
            Just _ -> [ btnElement "go" Go
                      , btnElement "back" Reset
                      ])
    ]

-- elements
black = rgb255 0 0 0
white = rgb255 255 255 255
grey = rgb255 25 25 25
red = rgb255 255 0 0

inputElement msg modelField =
    Input.text [ Background.color grey
               , Element.focused [ Background.color grey
                                 ]
               , Font.color white
               , Font.extraBold
               , Font.center
               , Font.family [ Font.external
                                   { name = "Roboto"
                                   , url = "https://fonts.googleapis.com/css?family=Roboto"
                                   }
                             , Font.sansSerif
                             ]
               , Font.size 24
               , Border.color white
               , Border.rounded 5
               , Border.width 2
               ]
    { onChange = msg
    , text = modelField
    , placeholder = Nothing
    , label = Input.labelHidden ""
    }

btnElement str msg =
    Input.button [ Background.color white
                 , Element.focused [ Background.color white
                                   ]
                 , Element.mouseOver [ Font.color red
                                     ]
                 , Font.color grey
                 , Font.semiBold
                 , Font.family [ Font.external
                                     { name = "Roboto"
                                     , url = "https://fonts.googleapis.com/css?family=Roboto"
                                     }
                               , Font.monospace
                               ]
                 , Border.rounded 5
                 , Border.color black
                 , padding 10
                 ]
    { onPress = Just msg
    , label = text str
    }

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
        ]

decoder : D.Decoder Model
decoder = D.nullable statsDecoder

statsDecoder : D.Decoder Stats
statsDecoder =
  D.map5 Stats
    (D.field "totalGames" D.int)
    (D.field "stages" <| D.array D.string)
    (D.field "totalLengthSeconds" D.float)
    (D.field "players" <| D.array playerDecoder)
    (D.field "playerStats" <| D.array playerStatDecoder)


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
    D.map6 PlayerStat
        (D.field "totalDamage" D.float)
        (D.field "neutralWins" D.int)
        (D.field "counterHits" D.int)
        (D.field "avgApm" D.float)
        (D.field "avgOpeningsPerKill" D.float)
        (D.field "avgDamagePerOpening" D.float)

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

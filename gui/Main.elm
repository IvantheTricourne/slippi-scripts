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
import Task

-- model

type alias Model = Maybe Stats
type alias Stats =
    { totalGames : Int
    , stages : Array String
    , totalLengthSeconds : Float
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
    [ el [ Font.color white
         , centerX
         ] (text <| case model of
                        Nothing -> "Upload a JSON file"
                        Just stats -> "JSON loaded: " ++ String.fromInt stats.totalGames ++ " games found"
           )
    , row [ centerX
          , spacing 10
          ]
        (case model of
            Nothing -> [ btnElement "upload" JsonRequested
                       ]
            Just _ -> [ btnElement "go" Go
                      , btnElement "reupload" JsonRequested
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
                ]

decoder : D.Decoder Model
decoder = D.nullable statsDecoder

statsDecoder : D.Decoder Stats
statsDecoder =
  D.map3 Stats
    (D.field "totalGames" D.int)
    (D.field "stages" <| D.array D.string)
    (D.field "totalLengthSeconds" D.float)

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

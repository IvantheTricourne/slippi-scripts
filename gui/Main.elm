port module Main exposing (..)

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

type alias Model =
    { cur : Maybe File
    }

-- update

type Msg
    = SearchDir
    | ZipRequested
    | ZipSelected File
    | ZipLoaded Bytes

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SearchDir ->
            ( model
            , Cmd.none
            )
        ZipRequested ->
            ( model
            , Select.file [ "application/zip" ] ZipSelected
            )
        ZipSelected file ->
            ( { model | cur = Just file }
            , Task.perform ZipLoaded (File.toBytes file)
            )
        ZipLoaded _ ->
            ( model
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
         ] (text <| "Loaded: " ++ case model.cur of
                                      Nothing -> "none"
                                      Just file -> File.name file
           )
    , row [ centerX
          , spacing 10
          ]
        [ btnElement "go" SearchDir
        , btnElement "zip" ZipRequested
        ]
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
  E.object
    [ ("cur", case model.cur of
                  Nothing -> E.null
                  Just file -> E.null
      )
    ]


decoder : D.Decoder Model
decoder =
  D.map Model
    (D.field "cur" <| D.nullable File.decoder)

-- subscriptions
subscriptions : Model -> Sub Msg
subscriptions _ = Sub.none

-- main

init : E.Value -> ( Model, Cmd Msg )
init flags =
    ( case D.decodeValue decoder flags of
          Ok model -> model
          Err _ ->
              { cur = Nothing
              }
    , Cmd.none
    )

main = Browser.element
       { init = init
       , update = updateWithStorage
       , view = view
       , subscriptions = subscriptions
       }

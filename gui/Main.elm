port module Main exposing (..)

import Browser
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import Html exposing (Html)
import Json.Decode as D
import Json.Encode as E


-- model

type alias Model =
    { dir : String
    }

-- update

type Msg
    = DirChange String

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DirChange dir ->
            ( { model | dir = dir }
            , Cmd.none
            )

-- view
view : Model -> Html Msg
view model =
    Element.layout [ Background.color black
                   ] <|
    row [ centerX
        , centerY
        , spacing 3
        ]
        [ inputElement DirChange model.dir
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
    [ ("dir", E.string model.dir)
    ]


decoder : D.Decoder Model
decoder =
  D.map Model
    (D.field "dir" D.string)

-- subscriptions
subscriptions : Model -> Sub Msg
subscriptions _ = Sub.none

-- main

init : E.Value -> ( Model, Cmd Msg )
init flags =
    ( case D.decodeValue decoder flags of
          Ok model -> model
          Err _ -> { dir = "" }
    , Cmd.none
    )

main = Browser.element
       { init = init
       , update = updateWithStorage
       , view = view
       , subscriptions = subscriptions
       }

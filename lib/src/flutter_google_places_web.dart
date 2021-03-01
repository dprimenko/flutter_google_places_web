import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';
import 'package:dio/dio.dart';
import 'package:rainbow_color/rainbow_color.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_google_places_web/src/search_results_tile.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class FlutterGooglePlacesWeb extends StatefulWidget {
  ///[value] stores the clicked address data in
  ///FlutterGooglePlacesWeb.value['name'] = '1600 Amphitheatre Parkway, Mountain View, CA, USA';
  ///FlutterGooglePlacesWeb.value['streetAddress'] = '1600 Amphitheatre Parkway';
  ///FlutterGooglePlacesWeb.value['city'] = 'CA';
  ///FlutterGooglePlacesWeb.value['country'] = 'USA';
  static Map<String, String> value;

  ///[showResults] boolean shows results container
  static bool showResults = false;

  ///This is the API Key that is needed to communicate with google places API
  ///Get API Key: https://developers.google.com/places/web-service/get-api-key
  final String apiKey;

  ///Proxy to be used if having CORS XMLError or want to use for security
  final String proxyURL;

  ///The position, in the input term, of the last character that the service uses to match predictions.
  ///For example, if the input is 'Google' and the [offset] is 3, the service will match on 'Goo'.
  ///The string determined by the [offset] is matched against the first word in the input term only.
  ///For example, if the input term is 'Google abc' and the [offset] is 3, the service will attempt to match against 'Goo abc'.
  ///If no [offset] is supplied, the service will use the whole term. The [offset] should generally be set to the position of the text caret.
  final int offset;

  ///[sessionToken] is a boolean that enable/disables a UUID v4 session token. [sessionToken] is [true] by default.
  ///Google recommends using session tokens for all autocomplete sessions
  ///Read more about session tokens https://developers.google.com/places/web-service/session-tokens
  final bool sessionToken;

  ///Currently, you can use components to filter by up to 5 countries.
  ///Countries must be passed as a two character, ISO 3166-1 Alpha-2 compatible country code.
  ///For example: components=country:fr would restrict your results to places within France.
  ///Multiple countries must be passed as multiple country:XX filters, with the pipe character (|) as a separator.
  ///For example: components=country:us|country:pr|country:vi|country:gu|country:mp would restrict your results to places within the United States and its unincorporated organized territories.
  final String components;
  final InputDecoration decoration;
  final bool required;
  final Widget loader;
  final double initialLat;
  final double initialLng;

  final Function(double, double) selectedAddress;

  FlutterGooglePlacesWeb(
      {Key key,
      this.apiKey,
      this.proxyURL,
      this.offset,
      this.components,
      this.sessionToken = true,
      this.decoration,
      this.required,
      this.loader,
      this.initialLat,
      this.initialLng,
        this.selectedAddress
      });

  @override
  FlutterGooglePlacesWebState createState() => FlutterGooglePlacesWebState();
}

class FlutterGooglePlacesWebState extends State<FlutterGooglePlacesWeb>
    with SingleTickerProviderStateMixin {
  final controller = TextEditingController();
  GoogleMapController mapController;
  AnimationController _animationController;
  Animation<Color> _loadingTween;
  List<Address> displayedResults = [];
  String proxiedURL;
  String offsetURL;
  String componentsURL;
  String _sessionToken;
  var uuid = Uuid();

  Future<List<Address>> getLocationResults(String inputText) async {
    if (_sessionToken == null && widget.sessionToken == true) {
      setState(() {
        _sessionToken = uuid.v4();
      });
    }

    if (inputText.isEmpty) {
      setState(() {
        FlutterGooglePlacesWeb.showResults = false;
      });
    } else {
      setState(() {
        FlutterGooglePlacesWeb.showResults = true;
      });
    }

    String baseURL =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json';
    String input = Uri.encodeComponent(inputText);
    if (widget.proxyURL == null) {
      proxiedURL =
          '$baseURL?input=$input&key=${widget.apiKey}&sessiontoken=$_sessionToken';
    } else {
      proxiedURL =
          '${widget.proxyURL}$baseURL?input=$input&key=${widget.apiKey}&sessiontoken=$_sessionToken';
    }
    if (widget.offset == null) {
      offsetURL = proxiedURL;
    } else {
      offsetURL = proxiedURL + '&offset=${widget.offset}';
    }
    if (widget.components == null) {
      componentsURL = offsetURL;
    } else {
      componentsURL = offsetURL + '&components=${widget.components}';
    }
    Response response = await Dio().get(componentsURL);
    var predictions = response.data['predictions'];
    if (predictions != []) {
      displayedResults.clear();
    }

    for (var i = 0; i < predictions.length; i++) {
      String placeId = predictions[i]['place_id'];
      String name = predictions[i]['description'];
      String streetAddress =
          predictions[i]['structured_formatting']['main_text'];
      List<dynamic> terms = predictions[i]['terms'];
      String city = terms[terms.length - 2]['value'];
      String country = terms[terms.length - 1]['value'];
      displayedResults.add(Address(
        placeId: placeId,
        name: name,
        streetAddress: streetAddress,
        city: city,
        country: country,
      ));
    }

    return displayedResults;
  }

  selectResult(Address clickedAddress) async {
    String baseURL =
        'https://maps.googleapis.com/maps/api/place/details/json';

    if (widget.proxyURL == null) {
      proxiedURL =
      '$baseURL?place_id=${clickedAddress.placeId}&fields=geometry&key=${widget.apiKey}';
    } else {
      proxiedURL =
      '${widget.proxyURL}$baseURL?place_id=${clickedAddress.placeId}&fields=geometry&key=${widget.apiKey}';
    }
    Response response = await Dio().get(proxiedURL);

    mapController.animateCamera(CameraUpdate.newLatLng(LatLng(response.data['result']['geometry']['location']['lat'], response.data['result']['geometry']['location']['lng'])));

    setState(() {
      FlutterGooglePlacesWeb.showResults = false;
      controller.text = clickedAddress.name;
      FlutterGooglePlacesWeb.value['name'] = clickedAddress.name;
      FlutterGooglePlacesWeb.value['streetAddress'] =
          clickedAddress.streetAddress;
      FlutterGooglePlacesWeb.value['city'] = clickedAddress.city;
      FlutterGooglePlacesWeb.value['country'] = clickedAddress.country;
      FlutterGooglePlacesWeb.value['latitude'] = response.data['result']['geometry']['location']['lat'].toString();
      FlutterGooglePlacesWeb.value['longitude'] = response.data['result']['geometry']['location']['lng'].toString();
    });

    widget.selectedAddress(response.data['result']['geometry']['location']['lat'], response.data['result']['geometry']['location']['lng']);
  }

  @override
  void initState() {
    FlutterGooglePlacesWeb.value = {};
    _animationController =
        AnimationController(duration: Duration(seconds: 3), vsync: this);
    _loadingTween = RainbowColorTween([
      //Google Colors
      Color(0xFF4285F4), //Google Blue
      Color(0xFF0F9D58), //Google Green
      Color(0xFFF4B400), //Google Tellow
      Color(0xFFDB4437), //Google Red
    ]).animate(_animationController)
      ..addListener(() {
        setState(() {});
      });
    _animationController.forward();
    _animationController.repeat();
    super.initState();
  }

  final addressFormKey = GlobalKey<FormState>();

  getStyleMap(context) {
    return DefaultAssetBundle.of(context).loadString("mapstyle.json");
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      // alignment: Alignment.center,
      child: Stack(
        children: [
          //search field
          TextFormField(
            key: widget.key,
            controller: controller,
            decoration: widget.decoration,
            validator: (value) {
              if (widget.required == true && value.isEmpty) {
                return 'Introduzca una localización';
              }
              return null;
            },
            onChanged: (text) {
              setState(() {
                getLocationResults(text);
              });
            },
          ),
          Positioned.fill(top: 60, child: GoogleMap(
              initialCameraPosition: CameraPosition(
                  target: LatLng(
                    widget.initialLat,
                    widget.initialLng,
                  ),
                  zoom: 13),
              tiltGesturesEnabled: false,
              compassEnabled: false,
              zoomGesturesEnabled: false,
              zoomControlsEnabled: false,
              onMapCreated: (controller) {
                // final mapConfig = await getStyleMap(context);
                // controller.setMapStyle(mapConfig);
                setState(() {
                  mapController = controller;
                });
              },
              myLocationEnabled: true)),
          Positioned.fill(top: 60, child: FlutterGooglePlacesWeb.showResults
              ? Container(
            width: MediaQuery.of(context).size.width,
            child: displayedResults.isEmpty
                ? Container(
              child: (widget.loader != null) ? widget.loader : CircularProgressIndicator(
                valueColor: _loadingTween,
                strokeWidth: 6.0,
              ),
            )
                : ListView(
              children: displayedResults
                  .map((Address addressData) =>
                  SearchResultsTile(
                      addressData: addressData,
                      callback: selectResult,
                      address:
                      FlutterGooglePlacesWeb
                          .value))
                  .toList(),
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border:
              Border.all(color: Colors.grey[200], width: 0.5),
            ),
          )
              : Container(),),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    _animationController.dispose();
    super.dispose();
  }
}

class Address {
  String placeId;
  String name;
  String streetAddress;
  String city;
  String country;
  Address({this.placeId, this.name, this.streetAddress, this.city, this.country});
}

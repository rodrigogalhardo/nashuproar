/*
Name: Akshath Jain
Date: 1/8/18
Purpose: view an individual post/article
*/

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share/share.dart';
import 'Utils.dart';
import 'Gallery.dart';
import 'Colors.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html/dom.dart' as dom;

class ArticleView extends StatefulWidget{
  final String id;
  
  ArticleView({Key key, this.id}) : super(key: key);

  @override
  _ArticleViewState createState() => _ArticleViewState();
}

class _ArticleViewState extends State<ArticleView>{
  Map _info; //the info about the articlew
  bool _hasGallery = false;
  List _galleryIds;
  static const int PODCAST_CATEGORY = 137;

  @override
  void initState() {
    super.initState();
    fetchArticleInfo().then((Map m){
      if(mounted){
        setState(() {
          _info = m;

          //determines if article has a gallery
          List split = _info["content"]["rendered"].split(" ");
          if(split.indexOf("photoids") != -1){
            _hasGallery = true;
            _galleryIds = split[split.indexOf("photoids") + 2].toString().replaceAll("\'", "").replaceAll(";", "").split(","); //get the numbers
            for(int i = 0; i < _galleryIds.length; i++) //get rid of all extraneous stuff
              _galleryIds[i] = _galleryIds[i].toString().replaceAll(RegExp("[^0-9]"), "");
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context){
    return new Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            title: Text("Back"),
            forceElevated: true,
            floating: true,
            actions: <Widget>[
              IconButton(
                icon: Icon(Icons.share),
                onPressed: () => Share.share(_info == null ? "" : _info["link"]),
                tooltip: "Share",
              ),
              IconButton(
                icon: Icon(Icons.open_in_browser),
                onPressed: () => _launchLink(_info == null ? "" : _info["link"]),
                tooltip: "Open in browser",
              ),
            ],
          ),
          _createBody(),
        ],
      ),
    );
  }

  //the retracting toolbar requires sliver list => requires that body is List<Widget>
  //therefore, need to do some strange return processing stuff
  Widget _createBody(){
    //Case: the information still needs to be loaded
    if(_info == null)
      return SliverFillRemaining(child: Center(child: CircularProgressIndicator()),);
    
    double pads = 20.0;

    //Case: the information has already loaded
    return SliverList(
      delegate: SliverChildListDelegate([
        _hasGallery ? _getGallery() : _getFeaturedImage(),
        
       
        Padding( //title
          padding: EdgeInsets.fromLTRB(pads, 16.0, pads, 6.0),
          child:  Html(
            data: _info["title"]["rendered"],
            defaultTextStyle: getTitleLargeStyle(context),
          ), //title
        ),
        
        
        _getAuthor(pads), //author
        
        
        _showDate(_info["title"]["rendered"], getDate(DateTime.parse(_info["date"])), pads),
       
       
        _getPodcast(),
        
        
        Html(
          padding: EdgeInsets.only(left: pads, right: pads),
          data: _info["content"]["rendered"],
          onLinkTap: (url) => _launchLink(url),
          linkStyle: TextStyle(
            decoration: TextDecoration.underline,
            color: ACCENT_COLOR,
            decorationColor: ACCENT_COLOR
          ),
          defaultTextStyle: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark ? TEXT_ON_DARK : TEXT_ON_LIGHT,
            fontSize: 15.0
          ),
          customRender: (node, children){
            if (node is dom.Element) {
              switch (node.localName) {
                case "iframe":
                  return _getYouTubeVideo(node);
                  break;
                case "img":
                  if(_hasGallery && node.attributes["class"].contains("slideshow")) //remove first slideshow image from body
                    return Container();
                  break;
                case "div":
                  if(node.attributes.containsKey("class") && node.attributes["class"].contains("slideshow")){ //remove annoying gallery sticker, replace with instructions to view gallery
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[ Container(
                        margin: const EdgeInsets.fromLTRB(0.0, 2.0, 2.0, 20.0),
                        padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 4.0),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: ACCENT_COLOR,
                            width: 2.5
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        child: Text("Swipe through Images to View Gallery", style: TextStyle(fontWeight: FontWeight.w600),),
                      )
                    ]);
                  }
                  break;
              }
            }
          },
        ), //article content
        SizedBox(height: 35.0,), //some final padding at the bottom
      ]),
    );
  }

  Widget _getFeaturedImage(){
    try{
      return Container(
        color: Colors.grey.shade200,
        child: AspectRatio(
          aspectRatio: 16.0/10.0,
          child: CachedNetworkImage(
            imageUrl: _info["_embedded"]["wp:featuredmedia"][0]["media_details"]["sizes"]["large"]["source_url"],
            fit: _getImageFit(),
          )
        )
      );
    }catch(NoSuchMethodError){
      return Container();
    }
  }

  BoxFit _getImageFit(){
    //case doesn't contain proper keys
    if(!_info["_embedded"]["wp:featuredmedia"][0].containsKey("media_details") || !_info["_embedded"]["wp:featuredmedia"][0]["media_details"].containsKey("height") || !_info["_embedded"]["wp:featuredmedia"][0]["media_details"].containsKey("width"))
      return BoxFit.cover;

    //width > height (landscape)
    if(_info["_embedded"]["wp:featuredmedia"][0]["media_details"]["width"] > _info["_embedded"]["wp:featuredmedia"][0]["media_details"]["height"])
      return BoxFit.cover;
    
    //height > width (portrait)
    return BoxFit.fitHeight;
  }

  Widget _getAuthor(double leftRightPadding){
    if(_info["_embedded"]["author"][0]["name"] == "adviser")
      return Container();
    
    return Padding( //author
          padding: EdgeInsets.fromLTRB(leftRightPadding, 0.0, leftRightPadding, 2.0),
          child: Text(
            _info["_embedded"]["author"][0]["name"] == "adviser" ? "Unknown Author" : _info["_embedded"]["author"][0]["name"],
            style: getAuthorStyle(context),
          ), //author
    );
  }

  //determines if article is podcast, if is, return link to listen
  Widget _getPodcast(){
    if(!_info.containsKey("categories") || !_info["categories"].contains(PODCAST_CATEGORY))
      return Container();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[RaisedButton(
          onPressed: () => _launchLink(_info["link"]),
          color: ACCENT_COLOR,
          child: Text("Listen to Podcast"),
        )],
      )
    );
  }

  Widget _getYouTubeVideo(var node){
    return Padding(
      padding: const EdgeInsets.fromLTRB(0.0, 2.0, 0.0, 15.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[ 
          Card(
            child: InkWell(
              onTap: () => _launchLink(node.attributes["src"]),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  CachedNetworkImage(
                    height: 180.0,
                    imageUrl: "https://img.youtube.com/vi/" + node.attributes["src"].split("/")[node.attributes["src"].split("/").length - 1] + "/1.jpg",
                    fit: BoxFit.cover,
                  ),
                  Icon(Icons.play_circle_filled, color: Colors.white, size: 50.0),
                ],
              ),
            ),
          ),
        ]
      )
    );
  }

  Widget _getGallery(){
    return AspectRatio(
      aspectRatio: 16.0 / 10.0,
      child: Gallery(
        ids: _galleryIds,
      )
    );
  }

  void _launchLink(String url) async{
    if(await canLaunch(url))
      await launch(url);
  }

  Widget _showDate(String title, String date, double leftRightPadding){
    if(title == date)
      return Container();
    
    return Padding(
      padding: EdgeInsets.fromLTRB(leftRightPadding, 0.0, leftRightPadding, 20.0),
      child: Text(
        date,
        style: getDateStyle(context),
      )
    );
  }

  Future<Map> fetchArticleInfo() async{
    final postInfo = await http.get("https://nashuproar.org/wp-json/wp/v2/posts/" + widget.id + "?_embed");
    return json.decode(postInfo.body);;
  }
}
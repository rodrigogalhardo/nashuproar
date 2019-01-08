/*
Name: Akshath Jain
Date: 1/8/18
Purpose: search view class for searching nash uproar
*/

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'Utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_html/flutter_html.dart';
import 'ArticleView.dart';

class SearchView extends StatefulWidget{
  SearchView({Key key}) : super(key: key);

  @override
  createState() => new _SearchView();
}

class _SearchView extends State<SearchView>{
  List _posts = new List();
  int _totalPages;
  int _page = 1;
  int _perpage = 25;
  bool _noResults = false;
  String _searchTerm = "";
  TextEditingController _inputController = new TextEditingController(); //used to clear the search text
  FocusNode _inputFocus = new FocusNode(); //used to focus input when search cleared

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: Colors.black,
        ),
        backgroundColor: Colors.white,
        title: new TextField(
          controller: _inputController,
          focusNode: _inputFocus,
          autofocus: true,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'Search',
          ),
          style: TextStyle(
            fontSize: 20.0, 
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
          onSubmitted: (String term){
            _page = 1;
            _searchTerm = term;
            _posts = new List();
            _noResults = false;
            _getMovies(term);
          }
        ),
        actions: <Widget>[
          _showClearSearch(),
        ],
      ),
      body: _createBody(),
    );
  }

  void _getMovies(String term){
    if(term != null || term != ""){
      fetchPosts(term).then((List l){
        if(mounted){
          setState((){
            _posts = l;
            // _totalPages = map['total_pages'];
            // List data = map['results'];
            
            // if(data != null && data.isNotEmpty){
            //   if(_movieData != null)
            //     _movieData.addAll(data);
            //   else
            //     _movieData = data;
            // }else{
            //   _noResults = true;
            // }
          });
        }
      });
    }    
  }

  Widget _createListView(){
    if(_posts == null)
      return new Container();
    else if(_posts.isEmpty)
      return new Center(child: Text('No results'),);

    return ListView.builder(
      itemCount: _posts.length,
      itemBuilder: (BuildContext context, int i){
        return Card(
          child: InkWell(
            onTap: () => _openPost(context, i),
            child: Row(
              children: <Widget>[
                _getFeaturedImage(i),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ConstrainedBox(
                      child: Html(
                        data: _posts[i]["title"]["rendered"],
                      ),
                      constraints: const BoxConstraints(maxWidth: 275.0),
                    ),
                    Text(getDate(DateTime.parse(_posts[i]["date"]))),
                  ],
                ),
              ],
            )
          ),
        );
      },
    );

    // return new ListView.builder(
    //   itemBuilder: (BuildContext context, int i){
    //     if(i < (_movieData.length + 2) ~/ 3){
    //       return buildMovieRow(context, _movieData, i, 'search-row-' + i.toString());
    //     }else{
    //       if(_page <= _totalPages)
    //         _getMovies(_searchTerm);
    //     }
    //   },
    // );
  }

  Widget _getFeaturedImage(int index){
    try{
      return CachedNetworkImage(
          imageUrl: _posts[index]["_embedded"]["wp:featuredmedia"][0]["media_details"]["sizes"]["thumbnail"]["source_url"],
      );
    }catch(NoSuchMethodError){
      return Text("");
    }
  }

  void _openPost(BuildContext context, int index){
    Navigator.of(context).push(
      new MaterialPageRoute(
        builder: (context){
          return new ArticleView(
            id: _posts[index]["id"].toString(),
          );
        }
      ),
    );
  }

  Widget _createBody(){
    if(_searchTerm == "")
      return Center(child: Text('Search for an article'),);

    if(_noResults)
      return Center(child: Text('No movies found',));

    if(_posts != null && _posts.isNotEmpty)
      return _createListView();
    else
      return Center(child: CircularProgressIndicator(),);    
  }

  Widget _showClearSearch(){
    if(_searchTerm != ""){
      return new IconButton(
        icon: Icon(Icons.clear),
        onPressed: (){
          _searchTerm = "";
          _inputController.clear();
          FocusScope.of(context).requestFocus(_inputFocus);
        },
      );
    }
    return Container();
  }

  //get the search stuff
  Future<List> fetchPosts(String searchTerm) async{
    final response = await http.get("https://nashuproar.org/wp-json/wp/v2/posts?search=" + searchTerm + "&page=" + _page.toString() + "&_embed&per_page=" + _perpage.toString());
    _page++;
    print(json.decode(response.body));
    return json.decode(response.body);
  }
}
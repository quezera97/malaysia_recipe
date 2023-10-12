import 'package:flutter/material.dart';
import 'package:malaysia_recipe/ui/favorite/favorite_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../api/youtube_api.dart';

class FavoritePlayList extends StatefulWidget {
  const FavoritePlayList({Key? key}) : super(key: key);

  @override
  State<FavoritePlayList> createState() => _FavoritePlayListState();
}

class _FavoritePlayListState extends State<FavoritePlayList> {
  List<String> dishUrl = [];
  List<YoutubePlayerController> _controllers = [];
  var responseYoutubeApi = [];
  int indexPrefs = 0;

  @override
  void initState() {
    super.initState();
    getDishUrl();
  }

  Future<void> getDishUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      dishUrl = prefs.getStringList('dishUrl') ?? [];
      
      _controllers = dishUrl.map((videoUrl) {
        return YoutubePlayerController(
          initialVideoId: getVideoId(videoUrl),
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            loop: true,
            hideThumbnail: true,
          ),
        );
      }).toList();
    });
  }

  Future<Map<String, dynamic>> callYoutubeApi(String videoUrl) async {
    final apiService = YoutubeApi();

    try {
      final videoDetailsMap = await apiService.getYoutubeDetails(videoUrl);

      if (videoDetailsMap.isNotEmpty) {
        return videoDetailsMap;
      } else {
        return {};
      }
    } catch (e) {
      return {};
    }
  }

  String getVideoId(url) {
    String? urlToId = YoutubePlayer.convertUrlToId(url);
    return urlToId ?? '';
  }

  @override
  void dispose() {
    super.dispose();
    for (var controller in _controllers) {
      controller.dispose();
    }
  }

  Future<void> removeVideoFromFavorites(int index) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    dishUrl.removeAt(index);
    await prefs.setStringList('dishUrl', dishUrl);

    _controllers[index].dispose();
    _controllers.removeAt(index);

    setState(() {
      dishUrl = List<String>.from(dishUrl);
    });
  }

  @override
  Widget build(BuildContext context) {
    final snackBar = SnackBar(
      content: const Text('Delete from favorite'),
      action: SnackBarAction(
        label: 'Yes!',
        onPressed: () {
          removeVideoFromFavorites(indexPrefs);
        },
      ),
    );

    if(_controllers.isEmpty){
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 100,
              width: 100,
              child: Image.asset('lib/assets/no-love.png'),
            ),
            const SizedBox(height: 10),
            const Text('No favorites available!'),
          ],
        )
      );
    }
    else{
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(5.0),
          child: ListView.separated(
            itemCount: _controllers.length,
            separatorBuilder: (context, _) => const SizedBox(height: 5.0),
            itemBuilder: (context, index) {
              return Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: FutureBuilder(
                  future: callYoutubeApi(dishUrl[index]),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Column(
                        children: const [
                          SizedBox(height: 5),
                          CircularProgressIndicator(),
                          SizedBox(height: 5),
                          Text(''),
                          SizedBox(height: 5),
                        ],
                      );
                    } else if (snapshot.hasError) {
                      return Text("Error: ${snapshot.error}");
                    } else {
                      var videoDetails = snapshot.data;
                      return SizedBox(
                        height: 90,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(10),
                          leading: InkWell(
                            child: Image.network(
                              videoDetails!['thumbnailUrl'],
                              fit: BoxFit.cover,
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => FavoritePlayer(
                                    controllers: _controllers, 
                                    index: index,
                                    title: videoDetails['title'],
                                  ),
                                ),
                              );
                            },
                          ),
                          title: Text(
                            videoDetails['title'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            videoDetails['authorName'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: () {
                              indexPrefs = index;

                              ScaffoldMessenger.of(context).showSnackBar(snackBar);
                            },
                          ),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          ),
        ),
      );
    }
  }
}
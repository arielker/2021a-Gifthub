import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:gifthub_2021a/AllReviewsScreen.dart';
import 'package:gifthub_2021a/user_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'chat.dart';
import 'globals.dart' as globals;
import 'package:gifthub_2021a/StoreScreen.dart';

/// ----------------------------------------------------
/// The Product Screen:
/// This is a generic widget that will show a product based
/// on the product Id it gets upon creation.
/// Contains single page with info about the product ('abot tab')
/// and some buttons with functionality that relates to the product.
/// Also allows a store owner to edit their product information.
/// ----------------------------------------------------

class ProductScreen extends StatefulWidget {
  final _productId;

  ProductScreen(String productId, {Key key}) : _productId = productId, super(key: key);
  @override
  _ProductScreenState createState() => _ProductScreenState(_productId);
}

class _ProductScreenState extends State<ProductScreen> {
  String _productId;
  globals.Product _prod;
  String _productImageURL;
  Image _productImage;
  Size _productImageSize;
  double _productRating;
  bool editingMode = false;
  GlobalKey<ScaffoldState> _scaffoldKeyProductScreenSet;
  final List controllers = <TextEditingController>[TextEditingController(), TextEditingController(), TextEditingController()];
  final TextEditingController reviewCtrl = TextEditingController();


  _ProductScreenState(String productId) : _productId = productId;

  @override
  void initState(){
    super.initState();
    _scaffoldKeyProductScreenSet = new GlobalKey<ScaffoldState>();
  }

  @override
  void dispose() {
    for(TextEditingController tec in controllers){
      tec.dispose();
    }
    super.dispose();
  }

  Future<void> _initProductArgs(DocumentSnapshot doc) async {
    var _prodArgs = doc.data()['Product'];
    _prod = globals.Product(
        _productId,
        _prodArgs['user'],
        _prodArgs['name'],
        double.parse(_prodArgs['price']),
        _prodArgs['date'],
        _prodArgs['reviews'],
        _prodArgs['category'],
        _prodArgs['description'],
        doc.data()['Options'] ?? globals.falseOptions,
    );
    /// Get the store's image from the storage if it exists or show a default image.
    Completer<Size> completer = Completer<Size>();
    try {
      _productImageURL = await FirebaseStorage.instance.ref().child('productImages/' + _productId).getDownloadURL();
      _productImage = Image.network(_productImageURL);
      _productImage.image.resolve(ImageConfiguration()).addListener(ImageStreamListener(
              (i, b) {
            completer.complete(Size(i.image.width.toDouble(), i.image.height.toDouble()));
          }
      ));
    } catch (e) {
      _productImageURL = null;
      _productImage = null;
      Image
          .asset('Assets/Untitled.png')
          .image
          .resolve(ImageConfiguration())
          .addListener(ImageStreamListener(
              (i, b) {
            completer.complete(Size(i.image.width.toDouble(), i.image.height.toDouble()));
          }
      ));
    } finally {
      _productImageSize = await completer.future;
    }
  }

  double _getProductRating() {
    double sum = 0.0;
    for (globals.Review r in _prod.reviews) {
      sum += r.rating;
    }
    return _prod.reviews.length != 0 ? sum / _prod.reviews.length : 0.0 ;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserRepository>(
        builder: (context, userRep, _) {
          return FutureBuilder(
              future: (() async {
                var prodDoc = userRep.firestore.collection('Products').doc(_productId);
                await _initProductArgs(await prodDoc.get());
                _getProductRating();
                _productRating = _getProductRating();
              })(),
              builder: (context, snapshot) {
                if(snapshot.connectionState == ConnectionState.done) {
                  return Material(
                      color: Colors.lightGreen,
                      child: Scaffold(
                        key: _scaffoldKeyProductScreenSet,
                        resizeToAvoidBottomInset: false,
                        resizeToAvoidBottomPadding: false,
                        backgroundColor: Colors.lightGreen[600],
                        appBar: AppBar(
                          backgroundColor: Colors.lightGreen[800],
                          title: editingMode?
                          TextField(
                            controller: controllers[0],
                            style: globals.calistogaFont(),
                          )
                              : Text(_prod.name, style: globals.calistogaFont(),),
                          ///Let the user edit and save product changes only if it's the owner
                          actions: userRep.status == Status.Authenticated && _prod.user == userRep.user.uid ?
                          editingMode ? [IconButton(icon: Icon(Icons.save_outlined), onPressed: () async {
                            await userRep.firestore.collection('Products').doc(_productId).get().then((snapshot) async {
                              var prodArgs = snapshot['Product'];
                              prodArgs['name'] = controllers[0].text;
                              prodArgs['description'] = controllers[1].text;
                              prodArgs['price'] = controllers[2].text;
                              await userRep.firestore.collection('Products').doc(_productId).update({'Product': prodArgs});
                            });
                            setState(() {
                              editingMode = false;
                            });
                          },)
                          ]
                              : [
                            IconButton(icon: Icon(Icons.edit_outlined), onPressed: () async {
                              await userRep.firestore.collection('Products').doc(_productId).get().then((snapshot) {
                                var prodArgs = snapshot['Product'];
                                setState(() {
                                  controllers[0].text = prodArgs['name'];
                                  controllers[1].text = prodArgs['description'];
                                  controllers[2].text = prodArgs['price'];
                                  editingMode = true;
                                });
                              });
                            }),
                          ] : [],
                        ),

                        body: SingleChildScrollView(
                          child: Column(
                            children: [
                              editingMode?
                              InkWell(
                                onLongPress: () async {
                                  PickedFile photo = await ImagePicker().getImage(source: ImageSource.gallery);
                                  if (null == photo) {
                                    _scaffoldKeyProductScreenSet.currentState.showSnackBar(
                                        SnackBar(
                                          content: Text("No image selected",
                                            style: GoogleFonts.notoSans(fontSize: 14.0),
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                          duration: Duration(milliseconds: 2500),
                                        )
                                    );
                                  } else {
                                    await FirebaseStorage.instance.ref().child('productImages/' + _productId).putFile(File(photo.path));
                                    setState(() { });
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(width: 5),
                                  ),
                                  child: Image(
                                    image: _productImage != null ? _productImage.image : AssetImage('Assets/Untitled.png'),
                                    width: min(min(MediaQuery
                                        .of(context).size.width, _productImageSize.width), MediaQuery.of(context).size.height * 0.25),
                                  ),
                                ),)
                                  : Container(
                                decoration: BoxDecoration(
                                  border: Border.all(width: 5),
                                ),
                                child: Image(
                                  width: min(min(MediaQuery.of(context).size.width, _productImageSize.width), MediaQuery.of(context).size.height * 0.25),
                                  image: _productImage != null ? _productImage.image : AssetImage('Assets/Untitled.png'),
                                ),
                              ),
                              SizedBox(height: 20.0),
                              SizedBox(height: 10.0),
                              editingMode?
                              TextField(
                                controller: controllers[1],
                                style: globals.niceFont(),
                              )
                                  : Text(
                                _prod.description,
                                style: globals.niceFont(size: 14.0),
                              ),
                              SizedBox(height: 10.0),
                              InkWell(
                                child: Text("Visit seller", style: globals.niceFont(size: 14.0, color: Colors.red[900]),),
                                onTap: () => {Navigator.of(context).push(MaterialPageRoute(builder: (context) => StoreScreen(_prod.user)))},
                              ),
                              SizedBox(height: 20.0),
                              globals.fixedStarBar(_productRating),
                              SizedBox(height: 20.0),
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    globals.regTextButton("All reviews (${_prod.reviews.length})", icon: Icon(Icons.list_alt_outlined), buttonColor: Colors.white, textColor: Colors.red, press: () {
                                      Navigator.of(context).push(MaterialPageRoute(builder: (context) => AllReviewsScreen(_prod.reviews)));
                                    }),
                                    globals.regTextButton("Add review", icon: Icon(Icons.add_outlined), buttonColor: Colors.white, textColor: Colors.red, press: () {
                                      if(userRep.status != Status.Authenticated){
                                        _scaffoldKeyProductScreenSet.currentState.showSnackBar(SnackBar(content: Text("Sign in to use this feature")));
                                        return;
                                      }
                                      if(userRep.user.uid == _prod.user) {
                                        _scaffoldKeyProductScreenSet.currentState.showSnackBar(SnackBar(content: Text("You can't add a review to your own product")));
                                        return;
                                      }
                                      _getReviewBottomSheet();
                                    }),

                                  ]
                              ),
                              SizedBox(height: 20.0),
                              editingMode?
                              TextField(
                                controller: controllers[2],
                                style: globals.niceFont(),
                              )
                                  : Text(
                                '\$' + _prod.price.toString(),
                                style: globals.niceFont(size: 30.0),
                              ),
                              SizedBox(height: 20.0),
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    globals.regTextButton("Add to Cart", icon: Icon(Icons.add_shopping_cart_outlined), press: () async {
                                      try {
                                        int beforeAdd = globals.userCart.length;
                                        await showDialog(context: context, builder: (BuildContext context) => AddToCartDialogBox(_prod));
                                        if(beforeAdd == globals.userCart.length){
                                          return;
                                        }
                                        _scaffoldKeyProductScreenSet.currentState.showSnackBar(SnackBar(content: Text("Item added to cart")));
                                      } catch(e) {
                                        _scaffoldKeyProductScreenSet.currentState.showSnackBar(SnackBar(content: Text("There was a problem")));
                                      }

                                    }),
                                  ]
                              ),
                              SizedBox(height: 20.0),
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                  globals.regTextButton("Contact Seller", icon: Icon(Icons.mail_outline), buttonColor: Colors.white, textColor: Colors.red, press: () async {
                                    String peerAvatar="https://cdn.vox-cdn.com/thumbor/mXo5ObKpTbHYi9YslBy6YhfedT4=/95x601:1280x1460/1200x800/filters:focal(538x858:742x1062)/cdn.vox-cdn.com/uploads/chorus_image/image/66699060/mgidarccontentnick.comc008fa9d_d.0.png";
                                    if(userRep.status != Status.Authenticated){
                                      _scaffoldKeyProductScreenSet.currentState.showSnackBar(SnackBar(content: Text("Sign in to use this feature")));
                                      return;
                                    }
                                    var peer=(await FirebaseFirestore.instance.collection("Users").doc(_prod.user).get())['Info'];
                                    try {
                                      peerAvatar =
                                      await FirebaseStorage.instance
                                          .ref("userImages/")
                                          .child(_prod.user)
                                          .getDownloadURL();
                                    }
                                    catch(e){
                                      peerAvatar="https://ui-avatars.com/api/?bold=true&background=random&name=" +
                                          peer[0]+"+"+peer[1];
                                    }
                                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => Scaffold(
                                      appBar: AppBar(
                                        centerTitle: true,
                                        elevation: 0.0,
                                        backgroundColor: Colors.lightGreen[800],
                                        leading: IconButton(
                                            icon: Icon(Icons.arrow_back),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            }),
                                        title: Text(
                                          "Chat with "+peer[0]+" "+peer[1],
                                          style: GoogleFonts.calistoga(
                                            fontSize: 26,
                                            color: Colors.white,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),

                                        body: Chat(userId: userRep.user.uid,peerId: _prod.user,peerAvatar:peerAvatar,)
                                    )));
                                  }),
                                  globals.regTextButton("Add to Wishlist", icon: Icon(Icons.favorite_outline_outlined), buttonColor: Colors.white, textColor: Colors.red, press: () async {
                                      if(userRep.status != Status.Authenticated){
                                        _scaffoldKeyProductScreenSet.currentState.showSnackBar(SnackBar(content: Text("Sign in to use this feature")));
                                        return;
                                      }
                                      var wishlist = (await FirebaseFirestore.instance.collection('Wishlists').doc(userRep.user.uid).get()).data()['Wishlist'];
                                      if(wishlist.contains(_productId)){
                                        _scaffoldKeyProductScreenSet.currentState.showSnackBar(SnackBar(content: Text("The product is already in your wishlist!")));
                                        return;
                                      }
                                      await FirebaseFirestore.instance.collection('Wishlists').doc(userRep.user.uid).update({
                                        'Wishlist': FieldValue.arrayUnion([_productId]),
                                      });
                                      _scaffoldKeyProductScreenSet.currentState.showSnackBar(SnackBar(content: Text("Product added to your wishlist")));
                                    }),
                                  ]
                              ),
                            ],
                          ),
                        ),
                      )
                  );
                }
                return globals.emptyLoadingScaffold();
              });
        }
    );
  }

  void _getReviewBottomSheet() {
    double _currReviewRating;
    showModalBottomSheet<dynamic>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context1) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery
                    .of(_scaffoldKeyProductScreenSet.currentContext)
                    .viewInsets
                    .bottom
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(height: 10,),
                globals.changingStarBar(0, onUpdate: (rating) {
                  _currReviewRating = rating;
                }, color: Colors.lightGreen[800]),
                SizedBox(height: 15.0,),
                Container(
                  width: MediaQuery
                      .of(context1)
                      .size
                      .width - 45,
                  height: 150,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(4.0))
                  ),
                  child: TextField(
                    controller: reviewCtrl,
                    decoration: InputDecoration(
                      hintText: "Write a review...",
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.lightGreen[800],
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.lightGreen[800],
                          width: 1.5,
                        ),
                      ),
                    ),
                    maxLines: null,
                    minLines: 5,
                    keyboardType: TextInputType.multiline,
                  ),
                ),
                SizedBox(height: 5.0,),
                Align(
                  alignment: FractionalOffset.bottomCenter,
                  child: Container(
                    width: 200,
                    child: RaisedButton(
                      color: Colors.white,
                      textColor: Colors.lightGreen[800],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.0),
                          side: BorderSide(
                            color: Colors.lightGreen[800],
                            width: 2.0,
                          )
                      ),
                      visualDensity: VisualDensity.adaptivePlatformDensity,
                      onPressed: () async {
                        var db = FirebaseFirestore.instance;
                        var prodArgs = (await db.collection('Products').doc(_productId).get()).data()['Product'];
                        prodArgs['reviews'].add({
                          'user': '',
                          'rating': _currReviewRating.toString(),
                          'content': reviewCtrl.text,
                        });
                        await db.collection('Products').doc(_productId).update({
                          'Product': prodArgs,
                        }).catchError((e) {
                          _scaffoldKeyProductScreenSet.currentState.showSnackBar(SnackBar(content: Text("There was a problem")));
                          return;
                        });
                        Navigator.of(context).pop();
                        setState(() {
                          reviewCtrl.text = '';
                        });
                      },
                      child: Text(
                        "Submit",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.openSans(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          // color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10.0,)
              ],
            ),
          );
        }
    );
  }
}

class AddToCartDialogBox extends StatefulWidget {
  final String title="Choose gift options",textConfirm="Add to Cart";
  globals.Product prod;

  @override
  _AddToCartDialogBoxState createState() => _AddToCartDialogBoxState();

  AddToCartDialogBox(globals.Product prod) : prod = prod;
}

class _AddToCartDialogBoxState extends State<AddToCartDialogBox> {
  Map optionsAnswers = {'wrapping': false, 'greeting': TextEditingController(), 'fast': false, 'special': TextEditingController()};

  @override
  Widget build(BuildContext context) {
    return Consumer<UserRepository>(
      builder: (context, userRep, _) =>
          Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(globals.Constants.padding),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: contentBox(context),
          ),
    );
  }

  contentBox(context) {
    var wrappingWidget = CheckboxListTile(
      title: Text("Wrap your gift?"),
      value: optionsAnswers['wrapping'],
      onChanged: (b) {
        setState(() {
          optionsAnswers['wrapping'] = b;
        });
      },
    );
    var greetingWidget = TextField(
      controller: optionsAnswers['greeting'],
      maxLines: null,
      minLines: 1,
      // expands: true,
      decoration: InputDecoration(
        hintText: "Add a greeting?",
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5.0),
          borderSide: BorderSide(
            color: Colors.amber,
            style: BorderStyle.solid,
          ),
        ),
      ),
    );
    var fastWidget = CheckboxListTile(
      title: Text("Do you want fast delivery?"),
        subtitle: Text("Extra charges may apply"),
        value: optionsAnswers['fast'],
        onChanged: (b) {
          setState(() {
            optionsAnswers['fast'] = b;
          });
        }
    );
    return Stack(
      children: <Widget>[
        Container(
          padding: EdgeInsets.only(top: 2.0),
          // margin: EdgeInsets.only(top: globals.Constants.avatarRadius),
          decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              color: Colors.white,
              borderRadius: BorderRadius.circular(globals.Constants.padding),
              boxShadow: [
                BoxShadow(color: Colors.black, offset: Offset(0, 10),
                    blurRadius: 10
                ),
              ]
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(widget.title, style: GoogleFonts.openSans(fontSize: MediaQuery
                    .of(context)
                    .size
                    .width * 0.06, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                widget.prod.options['wrapping'] ? wrappingWidget : Container(),
                widget.prod.options['wrapping'] ? SizedBox(height: 10.0) : Container(),
                widget.prod.options['fast'] ? fastWidget : Container(),
                widget.prod.options['fast'] ? SizedBox(height: 10.0) : Container(),
                widget.prod.options['greeting'] ? Container(
                    child:greetingWidget) : Container(),
                SizedBox(height: 10.0),
                Container(
                  child: TextField(
                    controller: optionsAnswers['special'],
                    maxLines: null,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: "Special requests?",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5.0),
                        borderSide: BorderSide(
                          color: Colors.amber,
                          style: BorderStyle.solid,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20.0),
                InkWell(
                  onTap: () async {
                    globals.userCart.add(widget.prod);
                    globals.userCartOptions.add({
                      'wrapping': optionsAnswers['wrapping'],
                      'greeting': optionsAnswers['greeting'].text,
                      'fast': optionsAnswers['fast'],
                      'special': optionsAnswers['special'].text,
                    });
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: EdgeInsets.only(top: MediaQuery
                        .of(context)
                        .size
                        .height * 0.02, bottom: MediaQuery
                        .of(context)
                        .size
                        .height * 0.02),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(globals.Constants.padding),
                          bottomRight: Radius.circular(globals.Constants.padding)),
                    ),
                    child: Text
                      (widget.textConfirm,
                      style: GoogleFonts.openSans(color: Colors.white, fontSize: MediaQuery
                          .of(context)
                          .size
                          .width * 0.05, fontWeight: FontWeight.w600,),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


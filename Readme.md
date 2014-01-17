## Introduction

A fast & minimalist embedded full-text indexing library, written in Objective-C, built on top of [Objective-LevelDB][2]. *It is still in development, obviously. You're welcomed to contribute if you find the project interesting!*

### Installation

By far, the easiest way to integrate this library in your project is by using [CocoaPods][1].

1. Have [Cocoapods][1] installed, if you don't already

2. In your Podfile, add the line (until it has been added to cocoapods main repo)

        pod 'MHTextSearch'

3. Run `pod install`

4. Add the `libc++.dylib` Framework to your project.

### Simple API

##### Create a embedded textual index 

```objective-c
MHTextIndex *index = [MHTextIndex textIndexInLibraryWithName:@"my.awesome.index"];
```

##### Index any objects

You can tell a `MHTextIndex` instance to index your objects (any object)

```objective-c
[index indexObject:anyObjectYouWant];
[index updateIndexForObject:anotherPreviousIndexedObject];
[index deleteIndexForObject:anotherPreviousIndexedObject];
```

But for this to work, you need to tell us what *identifier* as `NSData *` can be used to 
uniquely refer to this object.

```objective-c 
[index setIdentifier:^NSData *(MyCustomObject *object){
    return object.indexID; // a NSData instance
}];
```

You also need to give us details about the objects, like what are the pieces of text to
index

```objective-c 
[index setIndexer:^MHIndexedObject *(MyCustomObject *object, NSData *identifier){
    MHIndexedObject *indx = [MHIndexedObject new];
    indx.strings = @[ object.title, object.description ]; // Indexed strings
    indx.weight = object.awesomenessLevel;                // Weight given to this object, when sorting results
    indx.context = @{@"title": object.title};             // A NSDictionary that will be given alongside search results
    return indx;
}];
```

Finally, if you want to be able to get easy reference to your original object when you get
search results, you can tell us how to do that for you

```objective-c 
[index setObjectGetter:^MyCustomObject *(NSData *identifier){
    return [MyCustomObject customObjectFromIdentifier:identifier];
}];
```

and **that's it!** That's all you need to get a full-text index going. MHTextSearch takes care of
splitting text into words, factoring out diacritics and capitalization, all with respect to locale, as you'd expect 
(well, Foundation does most of the job here). 

You can then start searching:

```objective-c 
[index enumerateObjectsForKeyword:@"duck" options:0 withBlock:^(MHSearchResultItem *item, 
                                                                NSUInteger rank, 
                                                                NSUInteger count, 
                                                                BOOL *stop){
                                                                    
    item.weight;      // As provided by you earlier
    item.rank;        // The effective rank in the search result
    item.object;      // The first time it is used, it will use the block
                            // you provided earlier to get the object
    item.context;     // The dictionary you provided in the "indexer" block
    item.identifier;  // The object identifier you provided in the "identifier" block

    NSIndexPath *token = item.resultTokens[0]; 
    /* This is an NSArray of NSIndexPath instances, each containing 3 indices:
     *   - mh_string : the string in which the token occured 
     *                 (here, 0 for the object's title)
     *   - mh_word : the position in the string where the word containing
     *               the token occured
     *   - mh_token : the position in the word where the token occured
     */
                        
    NSRange tokenRange = [item rangeOfToken:token];
    /* This gives the exact range of the matched token in the string where it was found.
     *
     * So, according to the example setup I've been giving from the start,  
     * if token.mh_string == 0, that means the token was found in the object's "title",
     * and [item.object.title substringWithRange:tokenRange] would yield "duck" (minus 
     * capitalization and diacritics).
     */
}];
```

You can also fetch the whole array of `MHSearchResultItem` instances at once using

```objective-c
NSArray *resultSet = [index searchResultForKeyword:@"duck"
                                           options:NSEnumerationReverse];
```

##### Subclassing

If giving blocks for specifying behavior is not your thing, you can also override the following methods:

* `-[MHTextIndex getIdentifierForObject:]` which, by default uses the `identifier` block
* `-[MHTextIndex getIndexInfoForObject:andIdentifier:]` which, by default uses the `indexer` block
* `-[MHTextIndex compareResultItem:withItem:reversed:]` which is used to order the search result set

### Using with Core Data

You can use `NSManagedObject` lifecycle methods to trigger changes to the text index. The following example
was taken from
http://www.adevelopingstory.com/blog/2013/04/adding-full-text-search-to-core-data.html and adapted to use with
this project:

```objective-c

- (void)prepareForDeletion
{
    [super prepareForDeletion];

    if (self.indexID.length) {
        [textindex deleteIndexForObject:self.indexID];
    }
}

+ (NSData *)createIndexID {
    NSUUID *uuid = [NSUUID UUID];
    uuid_t uuidBytes;
    [uuid getUUIDBytes:uuidBytes];
    return [NSData dataWithBytes:uuidBytes length:16];
}

- (void)willSave
{
    [super willSave];

    if (self.indexID.length) {
        [textindex updateIndexForObject:self.indexID];
    } else {
        __block NSData *indexID = [[self class] createIndexID];
        [textindex indexObject:self.indexID];
        self.indexID = indexID;
    }
}
```

### Performance & Fine tuning

There are a few knobs you can play with to make MHTextSeach better fit your needs. 

- A `MHTextIndex` instance has a `skipStopWords` boolean property that is true by default and
  that avoids indexing very common english words. (**TODO**: make that work with other languages)

- It also has a `minimalTokenLength` that is equal to `2` by default. This sets a minimum for
  the number of letters that a token needs to be for it to be indexed. This also greatly minimizes
  the size of the index, as well as the indexing and searching time. It skips indexing single-letter
  words and the last letter of every word, when set to `2`.
  
- `MHTextIndex` uses a `NSOperationQueue` under the hood to coordinate indexing operations. It is 
  exposed as a property named `indexingQueue`. You can thus set its `maxConcurrentOperationCount`
  property to control how concurrent the indexing can be. Since the underlying database library
  performing I/O is thread-safe, concurrency is not a problem. This also means you can explicitly
  wait for indexing operations to finish using:
  
  ```objective-c
  [index.indexingQueue waitUntilAllOperationsAreFinished];
  ```
 
- Searching is also concurrent, but it uses a `dispatch_queue_t` (not yet exposed or tunable).

The following graphs show the indexing and searching time (in seconds), as a function of the size
of text indexed, ranging from 500 KB to about 10 MB. The benchmarks were run on an iPhone 5.

![](https://raw.github.com/matehat/MHTextSearch/master/MHTextSearch%20iOS%20Tests/benchmark.png)

### Testing

If you want to run the tests, you will need Xcode 5, as the test suite uses the new XCTest. 

Clone this repository and, once in it,

```bash
$ cd MHTextSearch\ iOS\ Tests
$ pod install
$ cd .. && open *.xcworkspace
```

Currently, all tests were setup to work with the iOS test suite.

### License

Distributed under the [MIT license](LICENSE)

[1]: http://cocoapods.org
[2]: https://github.com/matehat/Objective-LevelDB

#import "FirstViewController.h"
#import "UIImageView+WebCache.h"

@interface FirstViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imageView;

// 异步地清理磁盘缓存
@property (strong, nonatomic) dispatch_queue_t ioQueue;

@end

@implementation FirstViewController{
    NSFileManager *_fileManager;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
   [ self.imageView sd_setImageWithURL:[NSURL URLWithString:@"http://img15.3lian.com/2015/h1/280/d/4.jpg"] completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
       [[NSFileManager defaultManager] createFileAtPath:@"/Users/taojian/Desktop/fffff/s" contents:UIImagePNGRepresentation(image) attributes:nil];
   }];
    
    
    
    
//    [self.imageView sd_setImageWithURL:nil placeholderImage:nil options:0 progress:^(NSInteger receivedSize, NSInteger expectedSize) {
//        
//        
//    } completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
//        
//    }];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
}


// imageRefInfo信息
- (void)testImageRefInfo {
    UIImage *image = [UIImage imageNamed:@"Snip20150827_4"];
    CGImageRef imageRef = image.CGImage;
    CGImageAlphaInfo alpha = CGImageGetAlphaInfo(imageRef);
    CGColorSpaceModel imageColorSpaceModel = CGColorSpaceGetModel(CGImageGetColorSpace(imageRef));
    CGColorSpaceRef colorspaceRef = CGImageGetColorSpace(imageRef);
    size_t width = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);
}


@end

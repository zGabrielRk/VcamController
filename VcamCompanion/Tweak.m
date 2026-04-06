#import <Foundation/Foundation.h>

// Cria o diretório do VCam no boot do SpringBoard
// Necessário para que o VcamController app possa escrever temp.mov
__attribute__((constructor))
static void VcamCompanionInit(void) {
    @autoreleasepool {
        NSString *vcamDir = @"/var/jb/var/mobile/Library";
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:vcamDir]) {
            [fm createDirectoryAtPath:vcamDir
          withIntermediateDirectories:YES
                           attributes:nil
                                error:nil];
        }
    }
}

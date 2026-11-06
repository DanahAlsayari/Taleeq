#import <Foundation/Foundation.h>
#import "AudioProcessingAdapter.h"

NS_ASSUME_NONNULL_BEGIN

@interface AudioRecorder : NSObject <ExternalAudioProcessingDelegate>

- (BOOL)startRecordingToPath:(NSString *)path
                       error:(NSError **)error;

- (nullable NSString *)stopRecording;
- (double)currentAmplitude;
@property(nonatomic, readonly, getter=isRecording) BOOL recording;

@end

NS_ASSUME_NONNULL_END
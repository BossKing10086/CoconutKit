//
//  HLSViewBindingInformation.m
//  CoconutKit
//
//  Created by Samuel Défago on 18.06.13.
//  Copyright (c) 2013 Hortis. All rights reserved.
//

#import "HLSViewBindingInformation.h"

#import "HLSAssert.h"
#import "HLSLogger.h"
#import "HLSTransformer.h"
#import "NSBundle+HLSExtensions.h"
#import "NSError+HLSExtensions.h"
#import "NSObject+HLSExtensions.h"
#import "NSString+HLSExtensions.h"
#import "UIView+HLSViewBinding.h"

#import <objc/runtime.h>

@interface HLSViewBindingInformation ()

@property (nonatomic, weak) id object;
@property (nonatomic, strong) NSString *keyPath;
@property (nonatomic, strong) NSString *transformerName;
@property (nonatomic, weak) UIView *view;

@property (nonatomic, weak) id transformationTarget;
@property (nonatomic, assign) SEL transformationSelector;
@property (nonatomic, strong) NSString *errorDescription;

@property (nonatomic, weak) id<HLSBindingDelegate> delegate;

@property (nonatomic, assign, getter=isVerified) BOOL verified;

@end

@implementation HLSViewBindingInformation

#pragma mark Object creation and destruction

- (instancetype)initWithObject:(id)object keyPath:(NSString *)keyPath transformerName:(NSString *)transformerName view:(UIView *)view
{
    if (self = [super init]) {
        if (! [keyPath isFilled] || ! view) {
            HLSLoggerError(@"Binding requires at least a keypath and a view");
            return nil;
        }
        
        self.object = object;
        self.keyPath = keyPath;
        self.transformerName = transformerName;
        self.view = view;
    }
    return self;
}

- (instancetype)init
{
    HLSForbiddenInheritedMethod();
    return [self initWithObject:nil keyPath:nil transformerName:nil view:nil];
}

#pragma mark Getting and setting values

- (id)value
{
    // Lazily check and fill binding information
    if (! self.verified) {
        self.verified = [self verifyBindingInformation];
        if (! self.verified) {
            return nil;
        }
    }
            
    id value = [self.object valueForKeyPath:self.keyPath];
    return [self transformValue:value withTransformationTarget:self.transformationTarget transformationSelector:self.transformationSelector];
}

- (id)rawValue
{
    @try {
        return [self.object valueForKeyPath:self.keyPath];
    }
    @catch (NSException *exception) {
        return nil;
    }
}

#pragma mark Checking and updating values

- (BOOL)convertTransformedValue:(id)transformedValue toValue:(id *)pValue withError:(NSError **)pError
{
    id value = nil;
    if (! self.transformationTarget) {
        value = transformedValue;
    }
    else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id transformer = [self.transformationTarget performSelector:self.transformationSelector];
#pragma clang diagnostic pop
        NSAssert([transformer conformsToProtocol:@protocol(HLSTransformer)] || [transformer isKindOfClass:[NSFormatter class]], @"Invalid transformer");
        
        if ([transformer conformsToProtocol:@protocol(HLSTransformer)]) {
            // TODO: Check method availability, return error if not available
            if (! [transformer getObject:&value fromObject:transformedValue error:pError]) {
                return NO;
            }
        }
        else {
            NSString *errorDescription = nil;
            if (! [transformer getObjectValue:&value forString:transformedValue errorDescription:&errorDescription]) {
                if (pError) {
                    *pError = [NSError errorWithDomain:CoconutKitErrorDomain
                                                  code:HLSErrorTransformationError
                                  localizedDescription:errorDescription];
                }
                return NO;
            }
        }
    }
    
    if (! [self canDisplayValue:value]) {
        if (pError) {
            *pError = [NSError errorWithDomain:CoconutKitErrorDomain
                                          code:HLSErrorUnsupportedTypeError
                          localizedDescription:[NSString stringWithFormat:CoconutKitLocalizedString(@"The class %@ is not supported (supported are %@)", nil), [value class], [self supportedBindingClassesString]]];
        }
        return NO;
    }
    
    if (pValue) {
        *pValue = value;
    }
    
    return YES;
}

- (BOOL)checkValue:(id)value withError:(NSError **)pError
{
    // TODO: Implement call to -check method as well, since cleaner syntax
    return [self.object validateValue:&value forKeyPath:self.keyPath error:pError];
}

- (BOOL)updateWithValue:(id)value error:(NSError **)pError
{
    @try {
        [self.object setValue:value forKeyPath:self.keyPath];
    }
    @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:CoconutKitErrorDomain
                                             code:HLSErrorUpdateError
                             localizedDescription:CoconutKitLocalizedString(@"The value could not be updated", nil)];
        if (pError) {
            *pError = error;
        }
        HLSLoggerError(@"Cannot update object %@ with value %@ for key path %@: %@", self.object, value, self.keyPath, exception);
        return NO;
    }
    
    // Force a new verification (the value might have been nil, i.e. the information could not be verified, or
    // might have been set to nil)
    self.verified = [self verifyBindingInformation];
    
    return YES;
}

- (void)notifySuccess:(BOOL)success withValue:(id)value error:(NSError *)error
{
    if (! self.delegate) {
        return;
    }
    
    if (success && [self.delegate respondsToSelector:@selector(view:didValidateValue:forObject:keyPath:)]) {
        [self.delegate view:self.view didValidateValue:value forObject:self.object keyPath:self.keyPath];
    }
    else if (! success && [self.delegate respondsToSelector:@selector(view:didFailValidationForValue:object:keyPath:withError:)]) {
        [self.delegate view:self.view didFailValidationForValue:value object:self.object keyPath:self.keyPath withError:error];
    }
}

#pragma mark Binding

// Return YES if the binding information can be verified (keypath is valid, and any required transformation
// target and method could be located). If the information is valid but cannot not be fully checked (the keypath
// is correct, but returns nil), or if it is invalid, returns NO
- (BOOL)verifyBindingInformation
{
    // Just to visually check whether unnecessary verifications are made
    HLSLoggerDebug(@"Verifying binding information for %@", self);
    
    // An object has been provided. Check that the keypath is valid for it
    if (self.object) {
        @try {
            [self.object valueForKeyPath:self.keyPath];
        }
        @catch (NSException *exception) {
            self.errorDescription = @"The specified keypath is invalid for the bound object";
            return NO;
        }
    }
    // No object provided. Walk along the responder chain to find a responder matching the keypath (might be nil)
    else {
        self.object = [HLSViewBindingInformation bindingTargetForKeyPath:self.keyPath view:self.view];
    }
    
    if (! self.object) {
        self.errorDescription = @"No meaningful target was found along the responder chain for the specified keypath (stopping at view controller boundaries)";
        return NO;
    }
    
    // No need to check for exceptions here, the keypath is here guaranteed to be valid for the object
    id value = [self.object valueForKeyPath:self.keyPath];
    
    // Transformer lookup
    __block id transformationTarget = nil;
    __block SEL transformationSelector = NULL;
    
    if ([self.transformerName isFilled]) {
        // Check whether the transformer is a class method +[ClassName methodName]
        // Regex: ^\s*\+\s*\[(\w*)\s*(\w*)\]\s*$
        NSString *pattern = @"^\\s*\\+\\s*\\[(\\w*)\\s*(\\w*)\\]\\s*$";
        NSRegularExpression *classMethodRegularExpression = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                                                      options:0
                                                                                                        error:NULL];
        
        [classMethodRegularExpression enumerateMatchesInString:self.transformerName options:0 range:NSMakeRange(0, [self.transformerName length]) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
            // Extract capture group information
            NSString *className = [self.transformerName substringWithRange:[result rangeAtIndex:1]];
            NSString *methodName = [self.transformerName substringWithRange:[result rangeAtIndex:2]];
            
            // Check
            Class class = NSClassFromString(className);
            if (! class) {
                self.errorDescription = [NSString stringWithFormat:@"The specified global transformer points to an invalid class '%@'", className];
                return;
            }
            
            SEL selector = NSSelectorFromString(methodName);
            if (! class_getClassMethod(class, selector)) {
                self.errorDescription = [NSString stringWithFormat:@"The specified global transformer method '%@' does not exist for the class '%@'", methodName, className];
                return;
            }
            
            transformationTarget = class;
            transformationSelector = selector;
        }];
        
        // No class method transformer found yet
        if (! transformationTarget) {
            // Perform instance method lookup. First validate the method name
            // Regex: ^\s*(\w*)\s*$
            __block NSString *methodName = nil;
            NSString *pattern = @"^\\s*(\\w*)\\s*$";
            NSRegularExpression *methodNameRegularExpression = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                                                         options:0
                                                                                                           error:NULL];
            [methodNameRegularExpression enumerateMatchesInString:self.transformerName options:0 range:NSMakeRange(0, [self.transformerName length]) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                methodName = [self.transformerName substringWithRange:[result rangeAtIndex:1]];
            }];
            
            if ([methodName isFilled]) {
                transformationSelector = NSSelectorFromString(methodName);
            }
            
            if (! transformationSelector) {
                self.errorDescription = @"The transformer is not a valid method name";
                return NO;
            }
            
            // Look along the responder chain first (most specific)
            transformationTarget = [HLSViewBindingInformation bindingTargetForSelector:transformationSelector view:self.view];
            if (! transformationTarget) {
                // Look for an instance method on the object
                if ([self.object respondsToSelector:transformationSelector]) {
                    transformationTarget = self.object;
                }
                // Look for a class method on the object class itself (most generic)
                else if ([[self.object class] respondsToSelector:transformationSelector]) {
                    transformationTarget = [self.object class];
                }
                else {
                    self.errorDescription = @"The specified transformer is neither a valid global transformer, nor could be resolved along the responder chain (stopping at view controller boundaries)";
                    return NO;
                }
            }
        }
    }
    
    id displayedValue = [self transformValue:value withTransformationTarget:transformationTarget transformationSelector:transformationSelector];
    
    // We cannot cache binding information if we cannot check the type of the value to be displayed for compatibility. Does not change
    // the status, a later check is required
    if (! displayedValue) {
        return NO;
    }
    
    if (! [self canDisplayValue:displayedValue]) {
        self.errorDescription = [NSString stringWithFormat:@"The %@ must return one of the following supported types: %@",
                                 transformationTarget ? @"transformer" : @"keypath",
                                 [self supportedBindingClassesString]];
        return NO;
    }
    
    // Cache the binding information we just verified
    self.transformationTarget = transformationTarget;
    self.transformationSelector = transformationSelector;
    self.errorDescription = nil;
    
    // Locate the binding delegate, if any
    self.delegate = [HLSViewBindingInformation delegateForView:self.view];
    
    return YES;
}

#pragma mark Type checking

- (NSArray *)supportedBindingClasses
{
    Class viewClass = [self.view class];
    
    if ([viewClass respondsToSelector:@selector(supportedBindingClasses)]) {
        return [viewClass supportedBindingClasses];
    }
    else {
        return @[[NSString class]];
    }
}

- (NSString *)supportedBindingClassesString
{
    NSArray *supportedBindingClasses = [self supportedBindingClasses];
    NSMutableArray *classNames = [NSMutableArray array];
    for (Class supportedBindingClass in supportedBindingClasses) {
        [classNames addObject:NSStringFromClass(supportedBindingClass)];
    }
    return [classNames componentsJoinedByString:@", "];
}

- (BOOL)canDisplayValue:(id)value
{
    NSArray *supportedBindingClasses = [self supportedBindingClasses];
    for (Class supportedBindingClass in supportedBindingClasses) {
        if ([value isKindOfClass:supportedBindingClass]) {
            return YES;
        }
    }
    
    return NO;
}

#pragma mark Transformation

- (id)transformValue:(id)value withTransformationTarget:(id)transformationTarget transformationSelector:(SEL)transformationSelector
{
    if (! transformationTarget) {
        return value;
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    id transformer = [transformationTarget performSelector:transformationSelector];
#pragma clang diagnostic pop
    if ([transformer conformsToProtocol:@protocol(HLSTransformer)]) {
        return [transformer transformObject:value];
    }
    else if ([transformer isKindOfClass:[NSFormatter class]]) {
        return [transformer stringForObjectValue:value];
    }
    else {
        HLSLoggerError(@"The value cannot be transformed");
        return nil;
    }
}

#pragma mark Context binding lookup

+ (id<HLSBindingDelegate>)delegateForView:(UIView *)view
{
    UIResponder *responder = view;
    while (responder) {
        if ([responder conformsToProtocol:@protocol(HLSBindingDelegate)]) {
            return (id<HLSBindingDelegate>)responder;
        }
        
        // Does not get higher than the receiver parent view controller, which defines the binding context
        if ([responder isKindOfClass:[UIViewController class]]) {
            return nil;
        }
        
        responder = responder.nextResponder;
    }
    return nil;
}

// Locate the target which implements the specified method. Stops at view controller boundaries
+ (id)bindingTargetForSelector:(SEL)selector view:(UIView *)view
{
    UIResponder *responder = view;
    while (responder) {
        // Instance method lookup first
        if ([responder respondsToSelector:selector]) {
            return responder;
        }
        
        // Class method lookup
        Class responderClass = [responder class];
        if ([responderClass respondsToSelector:selector]) {
            return responderClass;
        }
        
        // Does not get higher than the receiver parent view controller, which defines the binding context
        if ([responder isKindOfClass:[UIViewController class]]) {
            return nil;
        }
        
        responder = responder.nextResponder;
    }
    return nil;
}

+ (id)bindingTargetForKeyPath:(NSString *)keyPath view:(UIView *)view
{
    UIResponder *responder = view;
    while (responder) {
        @try {
            // Will throw an exception unless the keypath is valid
            [responder valueForKeyPath:keyPath];
            return responder;
        }
        @catch (NSException *exception) {
            // Does not get higher than the receiver parent view controller, which defines the binding context
            if ([responder isKindOfClass:[UIViewController class]]) {
                return nil;
            }
            
            responder = responder.nextResponder;
        }
    }
    return nil;
}

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; object: %@; keyPath: %@; transformerName: %@; transformationTarget: %@; transformationSelector:%@>",
            [self class],
            self,
            self.object,
            self.keyPath,
            self.transformerName,
            self.transformationTarget,
            NSStringFromSelector(self.transformationSelector)];
}

@end
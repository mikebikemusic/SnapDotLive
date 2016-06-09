//
//  MyAlgo.h
//
//  Created by Mike on 6/7/16.
//  Copyright © 2016 Orologics. All rights reserved.
//

#import <Foundation/Foundation.h>

bool set_rgba_image(const size_t width, const size_t height, const size_t bytes_per_row, const uint8_t* pixels);
bool set_grey_image(const size_t width, const size_t height, const size_t bytes_per_row, const uint8_t* pixels);


@interface MyAlgo : NSObject {
@private
    
}


bool set_rgba_image(const size_t width, const size_t height, const size_t bytes_per_row, const uint8_t* pixels);
bool set_grey_image(const size_t width, const size_t height, const size_t bytes_per_row, const uint8_t* pixels);



@end

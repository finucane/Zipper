//
//  insist.h
//  Zipper
//
//  Created by finucane on 12/5/12.
//  Copyright (c) 2012 finucane. All rights reserved.
//

#define insist(e) if(!(e)) [NSException raise: @"assertion failed." format: @"%@:%d (%s)", [[NSString stringWithCString:__FILE__ encoding:NSUTF8StringEncoding] lastPathComponent], __LINE__, #e]

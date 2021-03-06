#import <Foundation/Foundation.h>

#import "GVCISO8601DateFormatter.h"
#import "GVCMacros.h"
#import "GVCLogger.h"
#import "NSString+GVCFoundation.h"

#ifndef DEFAULT_TIME_SEPARATOR
#       define DEFAULT_TIME_SEPARATOR ':'
#endif
unichar GVCISO8601DateFormatter_TimeSeparatorCharacter = DEFAULT_TIME_SEPARATOR;

//Unicode date formats.
#define ISO_CALENDAR_DATE_FORMAT @"yyyy-MM-dd"

//#define ISO_WEEK_DATE_FORMAT @"YYYY-'W'ww-ee" //Doesn't actually work because NSDateComponents counts the weekday starting at 1.
#define ISO_ORDINAL_DATE_FORMAT @"yyyy-DDD"
#define ISO_TIME_FORMAT @"HH:mm:ss"
#define ISO_TIME_WITH_TIMEZONE_FORMAT  ISO_TIME_FORMAT @"Z"

//printf formats.
#define ISO_TIMEZONE_UTC_FORMAT @"Z"
#define ISO_TIMEZONE_OFFSET_FORMAT @"%+02ld%02ld"

@interface GVCISO8601DateFormatter(UnparsingPrivate)

- (NSString *) replaceColonsInString:(NSString *)timeFormat withTimeSeparator:(unichar)timeSep;

- (NSString *) stringFromDate:(NSDate *)date formatString:(NSString *)dateFormat timeZone:(NSTimeZone *)timeZone;
- (NSString *) weekDateStringForDate:(NSDate *)date timeZone:(NSTimeZone *)timeZone;

@end

@implementation GVCISO8601DateFormatter

@synthesize defaultTimeZone;
@synthesize parsesStrictly;
@synthesize format;
@synthesize includeTime;
@synthesize timeSeparator;

- (id) init 
{
	self = [super init];
	if (self != nil) 
	{
        format = GVCISO8601DateFormatter_Calendar;
        timeSeparator = GVCISO8601DateFormatter_TimeSeparatorCharacter;
        includeTime = NO;
        parsesStrictly = NO;
    }
    return self;
}


//The following properties are only here because GCC doesn't like @synthesize in category implementations.

#pragma mark Parsing

static NSInteger read_segment(const unsigned char *str, const unsigned char **next, NSInteger *out_num_digits);
static NSInteger read_segment_4digits(const unsigned char *str, const unsigned char **next, NSInteger *out_num_digits);
static NSInteger read_segment_2digits(const unsigned char *str, const unsigned char **next);
static double read_double(const unsigned char *str, const unsigned char **next);
static BOOL is_leap_year(NSInteger year);

/*Valid ISO 8601 date formats:
 *
 *YYYYMMDD
 *YYYY-MM-DD
 *YYYY-MM
 *YYYY
 *YY //century 
 * //Implied century: YY is 00-99
 *  YYMMDD
 *  YY-MM-DD
 * -YYMM
 * -YY-MM
 * -YY
 * //Implied year
 *  --MMDD
 *  --MM-DD
 *  --MM
 * //Implied year and month
 *   ---DD
 * //Ordinal dates: DDD is the number of the day in the year (1-366)
 *YYYYDDD
 *YYYY-DDD
 *  YYDDD
 *  YY-DDD
 *   -DDD
 * //Week-based dates: ww is the number of the week, and d is the number (1-7) of the day in the week
 *yyyyWwwd
 *yyyy-Www-d
 *yyyyWww
 *yyyy-Www
 *yyWwwd
 *yy-Www-d
 *yyWww
 *yy-Www
 * //Year of the implied decade
 *-yWwwd
 *-y-Www-d
 *-yWww
 *-y-Www
 * //Week and day of implied year
 *  -Wwwd
 *  -Www-d
 * //Week only of implied year
 *  -Www
 * //Day only of implied week
 *  -W-d
 */

- (NSDateComponents *) dateComponentsFromString:(NSString *)string 
{
    return [self dateComponentsFromString:string timeZone:NULL];
}
- (NSDateComponents *) dateComponentsFromString:(NSString *)string timeZone:(out NSTimeZone **)outTimeZone 
{
    return [self dateComponentsFromString:string timeZone:outTimeZone range:NULL];
}

- (NSDateComponents *) dateComponentsFromString:(NSString *)string timeZone:(out NSTimeZone **)outTimeZone range:(out NSRange *)outRange 
{
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    calendar.firstWeekday = 2; //Monday
    NSDate *now = [NSDate date];
    
    NSDateComponents *components = [[NSDateComponents alloc] init];
    NSDateComponents *nowComponents = [calendar components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) fromDate:now];
    
    NSInteger
    //Date
    year,
    month_or_week,
    day,
    //Time
    hour = 0;

    NSTimeInterval
    minute = 0.0,
    second = 0.0;
    //Time zone
    NSInteger tz_hour = 0;
    NSInteger tz_minute = 0;
    
    enum {
        monthAndDate,
        week,
        dateOnly
    } dateSpecification = monthAndDate;
    
    BOOL strict = self.parsesStrictly;
    unichar timeSep = self.timeSeparator;
    
    if (strict) timeSep = GVCISO8601DateFormatter_TimeSeparatorCharacter;
    GVC_ASSERT(timeSep != '\0', @"Time separator must not be NUL.");
    
    BOOL isValidDate = ([string length] > 0);
    NSTimeZone *timeZone = nil;
    
    const unsigned char *ch = (const unsigned char *)[string UTF8String];
    
    NSRange range = { 0, 0 };
    const unsigned char *start_of_date;
    if (strict && isspace(*ch)) {
        range.location = NSNotFound;
        isValidDate = NO;
    }
	else
	{
        //Skip leading whitespace.
		NSUInteger len = strlen((const char *)ch);
		NSUInteger i;
        for ( i = 0 ; i < len; ++i)
		{
            if (!isspace(ch[i]))
                break;
        }
        
        range.location = i;
        ch += i;
        start_of_date = ch;
        
        NSInteger segment;
        NSInteger num_leading_hyphens = 0, num_digits = 0;
        
        if (*ch == 'T') {
            //There is no date here, only a time. Set the date to now; then we'll parse the time.
            isValidDate = isdigit(*++ch);
            
            year = (NSInteger)nowComponents.year;
            month_or_week = (NSInteger)nowComponents.month;
            day = (NSInteger)nowComponents.day;
        } else {
            //segment = 0;
            
            while(*ch == '-') {
                ++num_leading_hyphens;
                ++ch;
            }
            
            segment = read_segment(ch, &ch, &num_digits);
            switch(num_digits) {
                case 0:
                    if (*ch == 'W') {
                        if ((ch[1] == '-') && isdigit(ch[2]) && ((num_leading_hyphens == 1) || ((num_leading_hyphens == 2) && !strict))) {
                            year = (NSInteger)nowComponents.year;
                            month_or_week = 1;
                            ch += 2;
                            goto parseDayAfterWeek;
                        } else if (num_leading_hyphens == 1) {
                            year = (NSInteger)nowComponents.year;
                            goto parseWeekAndDay;
                        } else
                            isValidDate = NO;
                    } else
                        isValidDate = NO;
                    break;
                    
                case 8: //YYYY MM DD
                    if (num_leading_hyphens > 0)
                        isValidDate = NO;
                    else {
                        day = segment % 100;
                        segment /= 100;
                        month_or_week = segment % 100;
                        year = segment / 100;
                    }
                    break;
                    
                case 6: //YYMMDD (implicit century)
                    if (num_leading_hyphens > 0)
                        isValidDate = NO;
                    else {
                        day = segment % 100;
                        segment /= 100;
                        month_or_week = segment % 100;
                        year  = (NSInteger)nowComponents.year;
                        year -= (year % 100);
                        year += segment / 100;
                    }
                    break;
                    
                case 4:
                    switch(num_leading_hyphens) {
                        case 0: //YYYY
                            year = segment;
                            
                            if (*ch == '-') ++ch;
                            
                            if (!isdigit(*ch)) {
                                if (*ch == 'W')
                                    goto parseWeekAndDay;
                                else
                                    month_or_week = day = 1;
                            } else {
                                segment = read_segment(ch, &ch, &num_digits);
                                switch(num_digits) {
                                    case 4: //MMDD
                                        day = segment % 100;
                                        month_or_week = segment / 100;
                                        break;
                                        
                                    case 2: //MM
                                        month_or_week = segment;
                                        
                                        if (*ch == '-') ++ch;
                                        if (!isdigit(*ch))
                                            day = 1;
                                        else
                                            day = read_segment(ch, &ch, NULL);
                                        break;
                                        
                                    case 3: //DDD
                                        day = segment % 1000;
                                        dateSpecification = dateOnly;
                                        if (strict == YES)
										{
											if (((is_leap_year(year) == YES) && (day > 366)) || (day > 365))
												isValidDate = NO;
										}
                                        break;
                                        
                                    default:
                                        isValidDate = NO;
                                }
                            }
                            break;
                            
                        case 1: //YYMM
                            month_or_week = segment % 100;
                            year = segment / 100;
                            
                            if (*ch == '-') ++ch;
                            if (!isdigit(*ch))
                                day = 1;
                            else
                                day = read_segment(ch, &ch, NULL);
                            
                            break;
                            
                        case 2: //MMDD
                            day = segment % 100;
                            month_or_week = segment / 100;
                            year = (NSInteger)nowComponents.year;
                            
                            break;
                            
                        default:
                            isValidDate = NO;
                    } //switch(num_leading_hyphens) (4 digits)
                    break;
                    
                case 1:
                    if (strict) {
                        //Two digits only - never just one.
                        if (num_leading_hyphens == 1) {
                            if (*ch == '-') ++ch;
                            if (*++ch == 'W') {
                                year  = (NSInteger)nowComponents.year;
                                year -= (year % 10);
                                year += segment;
                                goto parseWeekAndDay;
                            } else
                                isValidDate = NO;
                        } else
                            isValidDate = NO;
                        break;
                    }
                case 2:
                    switch(num_leading_hyphens) {
                        case 0:
                            if (*ch == '-') {
                                //Implicit century
                                year  = (NSInteger)nowComponents.year;
                                year -= (year % 100);
                                year += segment;
                                
                                if (*++ch == 'W')
                                    goto parseWeekAndDay;
                                else if (!isdigit(*ch)) {
                                    goto centuryOnly;
                                } else {
                                    //Get month and/or date.
                                    segment = read_segment_4digits(ch, &ch, &num_digits);
                                    GVCLogInfo(@"(%@) parsing month; segment is %u and ch is %s", string, segment, ch);
                                    switch(num_digits) {
                                        case 4: //YY-MMDD
                                            day = segment % 100;
                                            month_or_week = segment / 100;
                                            break;
                                            
                                        case 1: //YY-M; YY-M-DD (extension)
                                            if (strict) {
                                                isValidDate = NO;
                                                break;
                                            }
                                        case 2: //YY-MM; YY-MM-DD
                                            month_or_week = segment;
                                            if (*ch == '-') {
                                                if (isdigit(*++ch))
                                                    day = read_segment_2digits(ch, &ch);
                                                else
                                                    day = 1;
                                            } else
                                                day = 1;
                                            break;
                                            
                                        case 3: //Ordinal date.
                                            day = segment;
                                            dateSpecification = dateOnly;
                                            break;
                                    }
                                }
                            } else if (*ch == 'W') {
                                year  = (NSInteger)nowComponents.year;
                                year -= (year % 100);
                                year += segment;
                                
                            parseWeekAndDay: //*ch should be 'W' here.
                                if (!isdigit(*++ch)) {
                                    //Not really a week-based date; just a year followed by '-W'.
                                    if (strict)
                                        isValidDate = NO;
                                    else
                                        month_or_week = day = 1;
                                } else {
                                    month_or_week = read_segment_2digits(ch, &ch);
                                    if (*ch == '-') ++ch;
                                parseDayAfterWeek:
                                    day = isdigit(*ch) ? read_segment_2digits(ch, &ch) : 1;
                                    dateSpecification = week;
                                }
                            } else {
                                //Century only. Assume current year.
                            centuryOnly:
                                year = segment * 100 + (NSInteger)nowComponents.year % 100;
                                month_or_week = day = 1;
                            }
                            break;
                            
                        case 1:; //-YY; -YY-MM (implicit century)
                            GVCLogInfo(@"(%@) found %u digits and one hyphen, so this is either -YY or -YY-MM; segment (year) is %u", string, num_digits, segment);
                            NSInteger current_year = (NSInteger)nowComponents.year;
                            NSInteger centYr = (current_year % 100);
                            year = segment + (current_year - centYr);
                            if (num_digits == 1) //implied decade
                                year += centYr - (current_year % 10);
                            
                            if (*ch == '-') {
                                ++ch;
                                month_or_week = read_segment_2digits(ch, &ch);
                                GVCLogInfo(@"(%@) month is %u", string, month_or_week);
                            }
                            
                            day = 1;
                            break;
                            
                        case 2: //--MM; --MM-DD
                            year = (NSInteger)nowComponents.year;
                            month_or_week = segment;
                            if (*ch == '-') {
                                ++ch;
                                day = read_segment_2digits(ch, &ch);
                            }
                            break;
                            
                        case 3: //---DD
                            year = (NSInteger)nowComponents.year;
                            month_or_week = (NSInteger)nowComponents.month;
                            day = segment;
                            break;
                            
                        default:
                            isValidDate = NO;
                    } //switch(num_leading_hyphens) (2 digits)
                    break;
                    
                case 7: //YYYY DDD (ordinal date)
                    if (num_leading_hyphens > 0)
                        isValidDate = NO;
                    else {
                        day = segment % 1000;
                        year = segment / 1000;
                        dateSpecification = dateOnly;
						if (strict == YES)
						{
							if (((is_leap_year(year) == YES) && (day > 366)) || (day > 365))
								isValidDate = NO;
						}
                    }
                    break;
                    
                case 3: //--DDD (ordinal date, implicit year)
                    //Technically, the standard only allows one hyphen. But it says that two hyphens is the logical implementation, and one was dropped for brevity. So I have chosen to allow the missing hyphen.
                    if ((num_leading_hyphens < 1) || ((num_leading_hyphens > 2) && !strict))
                        isValidDate = NO;
                    else {
                        day = segment;
                        year = (NSInteger)nowComponents.year;
                        dateSpecification = dateOnly;
						if (strict == YES)
						{
							if (((is_leap_year(year) == YES) && (day > 366)) || (day > 365))
								isValidDate = NO;
						}
                    }
                    break;
                    
                default:
                    isValidDate = NO;
            }
        }
        
        if (isValidDate) {
            if (isspace(*ch) || (*ch == 'T')) ++ch;
            
            if (isdigit(*ch)) {
                hour = read_segment_2digits(ch, &ch);
                if (*ch == timeSep) {
                    ++ch;
                    if ((timeSep == ',') || (timeSep == '.')) {
                        //We can't do fractional minutes when '.' is the segment separator.
                        //Only allow whole minutes and whole seconds.
                        minute = read_segment_2digits(ch, &ch);
                        if (*ch == timeSep) {
                            ++ch;
                            second = read_segment_2digits(ch, &ch);
                        }
                    } else {
                        //Allow a fractional minute.
                        //If we don't get a fraction, look for a seconds segment.
                        //Otherwise, the fraction of a minute is the seconds.
                        minute = read_double(ch, &ch);
                        second = modf(minute, &minute);
                        if (second > DBL_EPSILON)
                            second *= 60.0; //Convert fraction (e.g. .5) into seconds (e.g. 30).
                        else if (*ch == timeSep) {
                            ++ch;
                            second = read_double(ch, &ch);
                        }
                    }
                }
                
                switch(*ch) {
                    case 'Z':
                        timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
                        break;
                        
                    case '+':
                    case '-':;
                        BOOL negative = (*ch == '-');
                        if (isdigit(*++ch)) {
                            //Read hour offset.
                            segment = *ch - '0';
                            if (isdigit(*++ch)) {
                                segment *= 10;
                                segment += *(ch++) - '0';
                            }
                            tz_hour = (signed)segment;
                            if (negative) tz_hour = -tz_hour;
                            
                            //Optional separator.
                            if (*ch == timeSep) ++ch;
                            
                            if (isdigit(*ch)) {
                                //Read minute offset.
                                segment = *ch - '0';
                                if (isdigit(*++ch)) {
                                    segment *= 10;
                                    segment += *ch - '0';
                                }
                                tz_minute = (signed)segment;
                                if (negative) tz_minute = -tz_minute;
                            }
                            
                            timeZone = [NSTimeZone timeZoneForSecondsFromGMT:(tz_hour * 3600) + (tz_minute * 60)];
                        }
                }
            }
        }
        
        if (isValidDate) {
            components.year = year;
            components.day = day;
            components.hour = hour;
            components.minute = minute;
            components.second = second;
            
            switch(dateSpecification) {
                case monthAndDate:
                    components.month = month_or_week;
                    break;
                    
                case week:;
                    //Adapted from <http://personal.ecu.edu/mccartyr/ISOwdALG.txt>.
                    //This works by converting the week date into an ordinal date, then letting the next case handle it.
                    NSInteger prevYear = year - 1;
                    NSInteger YY = prevYear % 100;
                    NSInteger C = prevYear - YY;
                    NSInteger G = YY + YY / 4;
                    NSInteger isLeapYear = (((C / 100) % 4) * 5);
                    NSInteger Jan1Weekday = (isLeapYear + G) % 7;
                    enum { monday, tuesday, wednesday, thursday/*, friday, saturday, sunday*/ };
                    components.day = ((8 - Jan1Weekday) + (7 * (Jan1Weekday > thursday))) + (day - 1) + (7 * (month_or_week - 2));
                    
                case dateOnly: //An "ordinal date".
                    break;
            }
        }
    } //if (!(strict && isdigit(ch[0])))
    
    if (outRange) {
        if (isValidDate)
            range.length = (NSUInteger)(ch - start_of_date);
        else
            range.location = NSNotFound;
        
        *outRange = range;
    }
    if (outTimeZone) {
        *outTimeZone = timeZone;
    }
    
    return components;
}

- (NSDate *) dateFromString:(NSString *)string 
{
    return [self dateFromString:string timeZone:NULL];
}

- (NSDate *) dateFromString:(NSString *)string timeZone:(out NSTimeZone **)outTimeZone 
{
    return [self dateFromString:string timeZone:outTimeZone range:NULL];
}

- (NSDate *) dateFromString:(NSString *)string timeZone:(out NSTimeZone **)outTimeZone range:(out NSRange *)outRange 
{
	NSDate *retValue = nil;
    NSTimeZone *timeZone = nil;
    NSDateComponents *components = [self dateComponentsFromString:string timeZone:&timeZone range:outRange];
    if (outTimeZone)
        *outTimeZone = timeZone;
	
	if (([components year] != NSUndefinedDateComponent) && ([components month] != NSUndefinedDateComponent) && ([components day] != NSUndefinedDateComponent))
	{
		NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
		[calendar setFirstWeekday:2];   //Monday
		[calendar setTimeZone:timeZone];
		retValue = [calendar dateFromComponents:components];
	}
	return retValue;
}

- (BOOL)getObjectValue:(id *)outValue forString:(NSString *)string errorDescription:(NSString **)error 
{
    NSDate *date = [self dateFromString:string];
    if (outValue)
        *outValue = date;
    return (date != nil);
}

#pragma mark Unparsing

- (NSString *) replaceColonsInString:(NSString *)timeFormat withTimeSeparator:(unichar)timeSep 
{
    if (timeSep != ':') {
        NSMutableString *timeFormatMutable = [timeFormat mutableCopy];
        [timeFormatMutable replaceOccurrencesOfString:@":"
										   withString:[NSString stringWithCharacters:&timeSep length:1]
											  options:NSBackwardsSearch | NSLiteralSearch
												range:(NSRange){ 0L, [timeFormat length] }];
        timeFormat = timeFormatMutable;
    }
    return timeFormat;
}

- (NSString *) stringFromDate:(NSDate *)date {
    NSTimeZone *timeZone = self.defaultTimeZone;
    if (!timeZone) timeZone = [NSTimeZone defaultTimeZone];
    return [self stringFromDate:date timeZone:timeZone];
}

- (NSString *) stringFromDate:(NSDate *)date timeZone:(NSTimeZone *)timeZone {
    switch (self.format) {
        case GVCISO8601DateFormatter_Calendar:
            return [self stringFromDate:date formatString:ISO_CALENDAR_DATE_FORMAT timeZone:timeZone];
        case GVCISO8601DateFormatter_Week:
            return [self weekDateStringForDate:date timeZone:timeZone];
        case GVCISO8601DateFormatter_Ordinal:
            return [self stringFromDate:date formatString:ISO_ORDINAL_DATE_FORMAT timeZone:timeZone];
        default:
            [NSException raise:NSInternalInconsistencyException format:@"self.format was %ld, not calendar (%ld), week (%ld), or ordinal (%ld)", (long)self.format, (long)GVCISO8601DateFormatter_Calendar, (long)GVCISO8601DateFormatter_Week, (long)GVCISO8601DateFormatter_Ordinal];
            return nil;
    }
}

- (NSString *) stringFromDate:(NSDate *)date formatString:(NSString *)dateFormat timeZone:(NSTimeZone *)timeZone {
    if (includeTime)
        dateFormat = [dateFormat stringByAppendingFormat:@"'T'%@", [self replaceColonsInString:ISO_TIME_FORMAT withTimeSeparator:self.timeSeparator]];
    
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    calendar.firstWeekday = 2; //Monday
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.formatterBehavior = NSDateFormatterBehavior10_4;
    formatter.dateFormat = dateFormat;
    formatter.calendar = calendar;
    
    NSString *str = [formatter stringForObjectValue:date];
    if (includeTime) 
    {
        NSInteger offset = (NSInteger)[timeZone secondsFromGMT];
        offset /= 60;  //bring down to minutes
        if (offset == 0)
            str = [str stringByAppendingString:ISO_TIMEZONE_UTC_FORMAT];
        else
            str = [str stringByAppendingFormat:ISO_TIMEZONE_OFFSET_FORMAT, (long)(offset / 60), (long)(offset % 60)];
    }
    return str;
}

- (NSString *) stringForObjectValue:(id)value {
    NSParameterAssert([value isKindOfClass:[NSDate class]]);
    
    return [self stringFromDate:(NSDate *)value];
}

/*Adapted from:
 *      Algorithm for Converting Gregorian Dates to ISO 8601 Week Date
 *      Rick McCarty, 1999
 *      http://personal.ecu.edu/mccartyr/ISOwdALG.txt
 */
- (NSString *) weekDateStringForDate:(NSDate *)date timeZone:(NSTimeZone *)timeZone {
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    calendar.timeZone = timeZone;
    NSDateComponents *components = [calendar components:NSYearCalendarUnit | NSWeekdayCalendarUnit | NSDayCalendarUnit fromDate:date];
    
    //Determine the ordinal date.
    NSDateComponents *startOfYearComponents = [calendar components:NSYearCalendarUnit fromDate:date];
    startOfYearComponents.month = 1;
    startOfYearComponents.day = 1;
    NSDateComponents *ordinalComponents = [calendar components:NSDayCalendarUnit fromDate:[calendar dateFromComponents:startOfYearComponents] toDate:date options:0];
    ordinalComponents.day += 1;
    
    enum {
        monday, tuesday, wednesday, thursday, friday, saturday, sunday
    };
    enum {
        january = 1, february, march,
        april, may, june,
        july, august, september,
        october, november, december
    };
    
    NSInteger year = (NSInteger)components.year;
    NSInteger week = 0;
    //The old unparser added 6 to [calendarDate dayOfWeek], which was zero-based; components.weekday is one-based, so we now add only 5.
    NSInteger dayOfWeek = (components.weekday + 5) % 7;
    NSInteger dayOfYear = (NSInteger)ordinalComponents.day;
    
    NSInteger prevYear = year - 1;
    
    BOOL yearIsLeapYear = is_leap_year(year);
    BOOL prevYearIsLeapYear = is_leap_year(prevYear);
    
    NSInteger YY = prevYear % 100;
    NSInteger C = prevYear - YY;
    NSInteger G = YY + YY / 4;
    NSInteger Jan1Weekday = (((((C / 100) % 4) * 5) + G) % 7);
    
    NSInteger weekday = ((dayOfYear + Jan1Weekday) - 1) % 7;
    
    if((dayOfYear <= (7 - Jan1Weekday)) && (Jan1Weekday > thursday)) {
        week = 52 + ((Jan1Weekday == friday) || ((Jan1Weekday == saturday) && prevYearIsLeapYear));
        --year;
    } else {
        NSInteger lengthOfYear = (yearIsLeapYear == YES ? 366 : 365);
        if((lengthOfYear - dayOfYear) < (thursday - weekday)) {
            ++year;
            week = 1;
        } else {
            NSInteger J = dayOfYear + (sunday - weekday) + Jan1Weekday;
            week = J / 7 - (Jan1Weekday > thursday);
        }
    }
    
    NSString *timeString;
    if(includeTime) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        unichar timeSep = self.timeSeparator;
        if (!timeSep) timeSep = GVCISO8601DateFormatter_TimeSeparatorCharacter;
        formatter.dateFormat = [self replaceColonsInString:ISO_TIME_WITH_TIMEZONE_FORMAT withTimeSeparator:timeSep];
        
        timeString = [formatter stringForObjectValue:self];
    }
    else
    {
        timeString = [NSString gvc_EmptyString];
    }
    
    return [NSString stringWithFormat:@"%ld-W%02ld-%02ld%@", (long)year, (long)week, (long)(dayOfWeek + 1), timeString];
}

@end

static NSInteger read_segment(const unsigned char *str, const unsigned char **next, NSInteger *out_num_digits)
{
    NSInteger num_digits = 0;
    NSInteger value = 0;
    
    while(isdigit(*str)) {
        value *= 10;
        value += *str - '0';
        ++num_digits;
        ++str;
    }
    
    if (next) *next = str;
    if (out_num_digits) *out_num_digits = num_digits;
    
    return value;
}
static NSInteger read_segment_4digits(const unsigned char *str, const unsigned char **next, NSInteger *out_num_digits)
{
    NSInteger num_digits = 0;
    NSInteger value = 0;
    
    if (isdigit(*str)) {
        value += *(str++) - '0';
        ++num_digits;
    }
    
    if (isdigit(*str)) {
        value *= 10;
        value += *(str++) - '0';
        ++num_digits;
    }
    
    if (isdigit(*str)) {
        value *= 10;
        value += *(str++) - '0';
        ++num_digits;
    }
    
    if (isdigit(*str)) {
        value *= 10;
        value += *(str++) - '0';
        ++num_digits;
    }
    
    if (next) *next = str;
    if (out_num_digits) *out_num_digits = num_digits;
    
    return value;
}
static NSInteger read_segment_2digits(const unsigned char *str, const unsigned char **next)
{
    NSInteger value = 0;
    
    if (isdigit(*str))
        value += *str - '0';
    
    if (isdigit(*++str)) {
        value *= 10;
        value += *(str++) - '0';
    }
    
    if (next) *next = str;
    
    return value;
}

//strtod doesn't support ',' as a separator. This does.
static double read_double(const unsigned char *str, const unsigned char **next) 
{
    double value = 0.0;
    
    if (str) {
        NSInteger int_value = 0;
        
        while(isdigit(*str)) {
            int_value *= 10;
            int_value += (*(str++) - '0');
        }
        value = int_value;
        
        if (((*str == ',') || (*str == '.'))) {
            ++str;
            
            register double multiplier, multiplier_multiplier;
            multiplier = multiplier_multiplier = 0.1;
            
            while(isdigit(*str)) {
                value += (*(str++) - '0') * multiplier;
                multiplier *= multiplier_multiplier;
            }
        }
    }
    
    if (next) *next = str;
    
    return value;
}

static BOOL is_leap_year(NSInteger year)
{
    return ((year % 4) == 0) && (((year % 100) != 0)  ||  ((year % 400) == 0));
}

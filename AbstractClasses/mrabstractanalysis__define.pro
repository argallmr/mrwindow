; docformat = 'rst'
;
; NAME:
;       MrAbstractAnalysis__Define
;
;*****************************************************************************************
;   Copyright (c) 2013, Matthew Argall                                                   ;
;   All rights reserved.                                                                 ;
;                                                                                        ;
;   Redistribution and use in source and binary forms, with or without modification,     ;
;   are permitted provided that the following conditions are met:                        ;
;                                                                                        ;
;       * Redistributions of source code must retain the above copyright notice,         ;
;         this list of conditions and the following disclaimer.                          ;
;       * Redistributions in binary form must reproduce the above copyright notice,      ;
;         this list of conditions and the following disclaimer in the documentation      ;
;         and/or other materials provided with the distribution.                         ;
;       * Neither the name of the <ORGANIZATION> nor the names of its contributors may   ;
;         be used to endorse or promote products derived from this software without      ;
;         specific prior written permission.                                             ;
;                                                                                        ;
;   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY  ;
;   EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES ;
;   OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT  ;
;   SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,       ;
;   INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED ;
;   TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR   ;
;   BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN     ;
;   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN   ;
;   ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH  ;
;   DAMAGE.                                                                              ;
;*****************************************************************************************
;
;+
;   The purpose of this method is to serve as an abstract class various cursor
;   capabilites.
;
;   SETUP::
;       Subclass must have the following properties::
;           ifocus:             Index into "allObjects" of the plot on which the analysis
;                               is to be performed.
;           allObjects:         An array containing the object references of each plot
;                               drawn in the window.
;
;       Plotted objects must have the following properties:
;           indep:              Independent data.
;           dep:                Dependent data.
;
;       Set the draw widget UValue and Event Procedure::
;           UVALUE = {object: self, method: 'Draw_Events'}
;           EVENT_PRO = 'your_event_handling_procedure_goes_here'
;
;       In the procedure specified by EVENT_PRO, use the Call_Method procedure::
;           Widget_Control, self.drawID, GET_UVALUE=event_handler
;           Call_Method, event_handler.method, event_handler.object, event
;
;   ANALYZING::
;       - Button and/or Motion events must be turned on for the draw widget.
;       - AMODE must be set to a valid analysis bit (see below).
;       - To turn on/off button or motion events::
;           * Use On_Off_Button_Events and On_Off_Motion_Events to turn on and off
;             button and motion events, respectively. See those methods for rules governing
;             'ON' and 'OFF' and the 'Draw_Events' method for the sequences of events.
;
;   ANALYSIS MENU::
;       1) Create a top level base containing a menu bar and a draw widget.
;       2) Pass the menu bar's widget ID to the Create_Analysis_Menu method.
;       3) Event handling for the menu is done internally by the Analysis_Menu_Events method.
;       4) Draw widget event handling must be configured as described above.
;
;   Cursor Options::
;       Get Data Point  -   A button click returns the [x,y] data coordinates. INDEP and
;                           DEP are then searched for the closest match and the result
;                           is printed to the display.
;       Get Interval    -   Button-down, drag, button-up sequence returns two data points
;                           that are printed to the display (e.g. two "Get Data Point")
;       Average         -   Compute the average within "Get Interval".
;       MVAB            -   Select an interval of magnetic field data over which a
;                           minimum variance analysis will be performed.
;       VHT             -   Select an interval of ion velocity data and another of
;                           magnetic field data. The deHoffmann-Teller velocity will then
;                           be computed.
;       None            -   Deselect and turn off Analysis menu buttons.
;
;   Cursor Bits::
;       0       -   None
;       1       -   Get Value
;       2       -   Get Interval
;       4+2     -   Average
;       8+2     -   MVAB
;       16+2    -   vHT
;
; :Author:
;   Matthew Argall::
;       University of New Hampshire
;       Morse Hall, Room 113
;       8 College Rd.
;       Durham, NH, 03824
;       matthew.argall@wildcats.unh.edu
;
; :Copyright:
;       Matthew Argall 2013
;
; :History:
;	Modification History::
;       07/07/2013  -   Written by Matthew Argall
;       07/11/2013  -   Average, Data_Range, and MVA methods are now callable from the
;                           command-line, and are not just widget event handlers. - MRA
;       07/15/2013  -   Set the NaN flag when taking the MEAN. - MRA
;-
;*****************************************************************************************
;+
;   Determine which "Analsyis Menu" button was pressed and tell the draw widget which
;   type of events to pay attention to.
;
; :Params:
;       EVENT:              in, required, type=structure
;                           An event structure returned by the windows manager.
;-
pro MrAbstractAnalysis::Analysis_Menu_Events, event
    compile_opt idl2
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        void = error_message()
        return
    endif
    
    ;Get the value of the button that cause the event
    widget_control, event.id, GET_VALUE=analysis_type
    
    ;Toggle the checked state of the menu button
    isSet = widget_info(event.id, /BUTTON_SET)
    isSet = ~isSet

    ;Get the button's siblings and uncheck them all
    parent = widget_info(event.id, /PARENT)
    kids = widget_info(parent, /ALL_CHILDREN)
    for i = 0, n_elements(kids) - 1 do widget_control, kids[i], SET_BUTTON=0
    
    case strupcase(analysis_type) of
        'NONE': begin
            ;Turn everything off and copy the pixmap
            self.amode = [0, 0, 0]
            self -> On_Off_Button_Events, /OFF
            self -> On_Off_Motion_Events, /OFF
            ptr_free, self.intervals
            return
        endcase
        
        'GET DATA VALUE': begin
            if isSet then begin
                self.amode = [1, 0, 0]
                self -> On_Off_Button_Events, /ON
            endif else begin
                self.amode = [0, 0, 0]
                self -> On_Off_Button_Events, /OFF
            endelse
        endcase
        
        'GET INTERVAL': begin
            if isSet then begin
                self.amode = [2, 0, 0]
                self -> On_Off_Button_Events, /ON
            endif else begin
                self.amode = [0, 0, 0]
                self -> On_Off_Button_Events, /OFF
            endelse
        endcase
        
        'AVERAGE': begin
            if isSet then begin
                self.amode = [4 + 2, 0, 0]
                self -> On_Off_Button_Events, /ON
            endif else begin
                self.amode = [0, 0, 0]
                self -> On_Off_Button_Events, /OFF
            endelse
        endcase
        
        'MVAB': begin
            if isSet then begin
                self.amode = [8 + 2, 0, 0]
                self -> On_Off_Button_Events, /ON
            endif else begin
                self.amode = [0, 0, 0]
                self -> On_Off_Button_Events, /OFF
            endelse
        endcase
        
        'VHT': begin
            if isSet then begin
                self.amode = [16 + 2, 0, 0]
                self -> On_Off_Button_Events, /ON
            endif else begin
                self.amode = [0, 0, 0]
                self -> On_Off_Button_Events, /OFF
            endelse
        endcase
                
        else: message, 'Button "' + analysis_type + '" unknown.'
    endcase

    ;Put a check mark by the button
    widget_control, event.id, SET_BUTTON=isSet
end



;+
;   Print the average value in a given interval.
;
; :Params:
;       XRANGE:             in, required, type=fltarr(3,3)
;                           The data range along the abscissa axis over which the average
;                               is to be taken.
;       LOCATION:           in, optional, type=intarr(2)
;                           The [col, row] location of the plot whose data is to be averaged.
;                               If not provided, the currently selected plot will be
;                               rotated (i.e. the one indexed by self.ifocus).
;
; :Keywords:
;       LIST_INDEX              in, optional, type=boolean, default=0
;                               If set, then `LOCATION` is actually the index within at
;                                   which the plot is stored.
;       PLOT_INDEX:             in, optional, type=int, default=0
;                               If set, then `LOCATION` is actually the 1D plot index of
;                                   the plot. The upper-left-most plot has a plot index of
;                                   1, and the plot index increases as you go down the
;                                   column, then across the row.
;-
pro MrAbstractAnalysis::Average, xrange, location, $
LIST_INDEX = list_index, $
PLOT_INDEX = plot_index
    compile_opt idl2
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        self -> Error_Handler
        void = error_message()
        return
    endif
    
;---------------------------------------------------------------------
;Check Inputs ////////////////////////////////////////////////////////
;---------------------------------------------------------------------

    ;Defaults
    list_index = keyword_set(list_index)
    plot_index = keyword_set(plot_index)

    ;Use the selected plot
    if n_elements(location) eq 0 then begin
        index = self.ifocus

    ;Check if the given location exists
    endif else begin
        exists = self -> plotExists(location, index, $
                                    PLOT_INDEX=plot_index, LIST_INDEX=list_index, $
                                    /TO_LIST_INDEX)
        if exists eq 0 then message, 'No plot exists at LOCATION. Returning.'
    endelse
    
;---------------------------------------------------------------------
;Get Data and Compute Average ////////////////////////////////////////
;---------------------------------------------------------------------
    
    ;Get the data interval
    !Null = self -> Data_Range(xrange, index, IRANGE=iRange)

    ;Retrieve the data and the dimension over which to take the mean
    (*self.allObjects)[index] -> GetProperty, INDEP=indep, DEP=dep, DIMENSION=dimension
    if n_elements(dimension) eq 0 then dimension = 0
    if dimension eq 2 && iRange[1] - iRange[0] + 1 eq 1 then dimension = 0

    ;Compute the average.
    x_avg = mean(indep[iRange[0]:iRange[1]], /NAN)
    case dimension of
        0: y_avg = mean(dep[iRange[0]:iRange[1]], /NAN)
        1: y_avg = mean(dep[iRange[0]:iRange[1],*], DIMENSION=dimension, /NAN)
        2: y_avg = mean(dep[*,iRange[0]:iRange[1]], DIMENSION=dimension, /NAN)
    endcase
    
;---------------------------------------------------------------------
;Print Results ///////////////////////////////////////////////////////
;---------------------------------------------------------------------
    ;XRange are the data coordinates of the clicked points.
    ;[x0, x1] are the actual data values over which the average is taken
    ;Xavg and Yavg are the x- and y-averages over the interval [x0,x1].

    x_avg = string(x_avg, FORMAT='(f0.4)')
    y_avg = '[' + strjoin(string(y_avg, FORMAT='(f0.4)'), ', ') + ']'
    print, FORMAT='(%"X Range  = [%0.4f, %0.4f]")', xrange
    print, FORMAT='(%"[x0, x1] = [%0.4f, %0.4f]")', indep[iRange]
    print, FORMAT='(%"  Xavg   = %s")', x_avg
    print, FORMAT='(%"  Yavg   = %s")', y_avg
end


;+
;   Create a menu bar with various analysis options in it.
;
; :Params:
;       PARENT:             in, required, type=integer
;                           The widget ID of the parent widget.
;
; :Keywords:
;       GET_DATA_VALUE:     in, optional, type=boolean, default=1
;                           Create the "Get Data Value" button.
;       GET_INTERVAL:       in, optional, type=boolean, default=1
;                           Create the "Get Interval" button.
;       AVERAGE:            in, optional, type=boolean, default=1
;                           Create the "Average" button.
;       MENU:               in, optional, type=boolean, default=1
;                           If set, all buttons will be placed under a "Analysis" submenu.
;       MVAB:               in, optional, type=boolean, default=1
;                           Create the "MVAB" button.
;       NONE:               in, optional, type=boolean, default=1
;                           Create the "None" button.
;-
pro MrAbstractAnalysis::Create_Analysis_Menu, parent, $
AVERAGE = average, $
GET_INTERVAL = get_interval, $
MENU = menu, $
MVAB = mvab, $
VHT = vHT, $
NONE = none
    compile_opt idl2
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        void = error_message()
        return
    endif
    
    setDefaultValue, menu, 1, /BOOLEAN
    setDefaultValue, get_data_value, 1, /BOOLEAN
    setDefaultValue, get_interval, 1, /BOOLEAN
    setDefaultValue, average, 1, /BOOLEAN
    setDefaultValue, mvab, 1, /BOOLEAN
    setDefaultValue, vHT, 1, /BOOLEAN
    setDefaultValue, none, 1, /BOOLEAN
    
    ;Create the Menu
    if keyword_set(menu) $
        then cursorID = widget_button(parent, VALUE='Analysis', /MENU) $
        else cursorID = parent
    
    ;Create the menu
    if keyword_set(get_data_value) then button = widget_button(cursorID, VALUE='Get Data Value', UNAME='GET_DATA_VALUE', /CHECKED_MENU, UVALUE={object: self, method: 'Analysis_Menu_Events'})
    if keyword_set(get_interval) then button = widget_button(cursorID, VALUE='Get Interval', UNAME='GET_INTERVAL', /CHECKED_MENU, UVALUE={object: self, method: 'Analysis_Menu_Events'})
    if keyword_set(average) then button = widget_button(cursorID, VALUE='Average', UNAME='AVERAGE', /CHECKED_MENU, UVALUE={object: self, method: 'Analysis_Menu_Events'})
    if keyword_set(mvab) then button = widget_button(cursorID, VALUE='MVAB', UNAME='MVAB', /CHECKED_MENU, UVALUE={object: self, method: 'Analysis_Menu_Events'})
    if keyword_set(vHT) then button = widget_button(cursorID, VALUE='vHT', UNAME='VHT', /CHECKED_MENU, UVALUE={object: self, method: 'Analysis_Menu_Events'})
    if keyword_set(none) then button = widget_button(cursorID, VALUE='None', UNAME='ANONE', UVALUE={object: self, method: 'Analysis_Menu_Events'})
end


;+
;   Find the nearest value to the point [x, y], given in data coordinates.
;
; :Params:
;       XRANGE:             in, required, type=numeric
;                           A range of coordinate on the abscissa for which the data
;                               interval is to be returned
;       INDEX:              in, optional, type=int, default=self.ifocus
;                           The index of the plot for which the data range is to be
;                               determined.
;
; :Keywords:
;       IRANGE:             out, optional, type=int
;                           Index value within the data array at which to find `XY_DATA`.
;                               it is ordered [sIndex, eIndex], where "s" and "e" denote
;                               the start and end of the data interval, respectively.
;
; :Returns:
;       XY_DATA:            The range of data corresponding to the coordinates `XRANGE`
;                               and `YRANGE`. It is ordered [[x0, y0, x1, y1], $
;                                                            [x0, y0, x1, y1]],
;                               where the different rows represent different components
;                               of the non-plotted dimension.
;-
function MrAbstractAnalysis::Data_Range, xrange, index, $
IRANGE = iRange
    compile_opt idl2
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        void = error_message()
        return, !Null
    endif
    
    setDefaultValue, index, self.ifocus
    
    ;Retrieve the data and the dimension over which to take the mean
    (*self.allObjects)[index] -> GetProperty, INDEP=indep, DEP=dep, DIMENSION=dimension
    if n_elements(dimension) eq 0 then dimension = 0
    
    ;Find the closest data point
    !Null = min(abs(indep - xrange[0]), sIndex)
    !Null = min(abs(indep - xrange[1]), eIndex)

    ;Store them
    x_data = indep[[sIndex, eIndex]]
    
    case dimension of
        0: y_data = reform(dep[[sIndex, eIndex]])           ;incase it is a column
        1: y_data = dep[[sIndex, eIndex],*]
        2: y_data = transpose(dep[*,[sIndex, eIndex]])
    endcase
    
    n = n_elements(y_data)/2
    
    ;Arrange them
    xy_data = [replicate(x_data[0], 1, n), y_data[0,*], replicate(x_data[1], 1, n), y_data[1,*]]
    iRange = [sIndex, eIndex]

    return, xy_data
end


;+
;   Handle events from the draw widget
;
; :Params:
;       EVENT:              in, required, type=structure
;                           An event structure returned by the windows manager.
;-
pro MrAbstractAnalysis::Draw_Events, event
    compile_opt idl2
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        self -> Error_Handler
        void = error_message()
        return
    endif
    
;---------------------------------------------------------------------
;Button Press Events /////////////////////////////////////////////////
;---------------------------------------------------------------------
    if event.type eq 0 then begin
        if self.amode eq 1 then self -> Get_Data_Point, event ;Get Interval, Average
        if ((self.amode and 2) gt 0) then self -> Get_Interval, event   ;Get Interval, Average, MVAB
    endif

;---------------------------------------------------------------------
;Motion Events ///////////////////////////////////////////////////////
;---------------------------------------------------------------------
    if event.type eq 2 then begin
        ;Do not compete for copying the pixmap: Get Interval
        if ((self.amode[0] and 2) gt 0) then self -> copyPixmap

        ;Handle motion events
        if self.amode[0] eq 1 then self -> Get_Data_Point, event
        if ((self.amode[0] and 2) gt 0) then self -> Get_Interval, event
    endif
end


;+
;   Determine which "Analsyis Menu" button was pressed and tell the draw widget which
;   type of events to pay attention to.
;
; :Params:
;       EVENT:              in, required, type=structure
;                           An event structure returned by the windows manager.
;-
pro MrAbstractAnalysis::Error_Handler
    compile_opt idl2
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        void = error_message()
        return
    endif

    self.amode = [0,0,0]
    self -> On_Off_Button_Events, /OFF
    self -> On_Off_Motion_Events, /OFf
    self.x0 = -1
    self.y0 = -1
    ptr_free, self.intervals
end



;+
;   Click and Drag the mouse to rubber band box in the display. When the mouse button
;   is released, the plot will be updated to the range encompassed by the box.
;
;   If the x- or y-coordinate does not change (i.e. the box is still a line), the zoom
;   will be 1-dimensional.
;
; :Params:
;       EVENT:              in, required, type=structure
;                           An event structure returned by the windows manager.
;-
pro MrAbstractAnalysis::Get_Interval, event
    compile_opt idl2
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        self -> Error_Handler
        void = error_message()
        return
    endif

    ;Return if we are not trying to "Get Interval"
    case event.type of
        0: if event.press ne 1 || ((self.amode[0] and 2) eq 0) then return      ;left button down
        1: if ((self.amode[0] and 2) eq 0) then return                          ;button up
        2: if self.amode[1] eq 0 || ((self.amode[0] and 2) eq 0) then return    ;motion
        else: return
    endcase

    ;If the button was pressed
    case event.type of
        0: begin    ;Button down
            ;Make active for motion events
            self.amode[1] = 1
        
            ;Store the clicked coordinates
            self.x0 = event.x
            self.y0 = event.y

            ;Turn on motion events
            self -> On_Off_Motion_Events, /ON
        endcase
        
        2: begin    ;Motion event
            ;Draw a |------| to indicate the interval being taken
            x_right_bar = [self.x0, self.x0, self.x0]
            y_right_bar = [self.y0+3, self.y0, self.y0-3]
            
            x_left_bar = [event.x, event.x, event.x]
            y_left_bar = [event.y+3, event.y, event.y-3]
            
            x_stem = [self.x0, event.x]
            y_stem = [self.y0, event.y]
            
            plots, x_right_bar, y_right_bar, color=load_color('blue'), /DEVICE
            plots, x_left_bar, y_left_bar, color=load_color('blue'), /DEVICE
            plots, x_stem, y_stem, color=load_color('blue'), /DEVICE
        endcase
        
        1: begin    ;Button up
            ;Turn off Box Zoom.
            self.amode[1] = [0]
            
            ;Turn motion events off right away (requires self.zmode=0)
            self -> On_Off_Motion_Events, /OFF

            ;Get rid of the box by copying the pixmap again
            self -> copyPixmap

            ;Order the clicks as [min, max]. Convert to data
            x = [self.x0 < event.x, self.x0 > event.x]
            y = [self.y0 < event.y, self.y0 > event.y]
            
            ;the interval must not be of 0 length (Use Get_Point for that).
            if self.x0 eq event.x && self.y0 eq event.y then return

            ;Convert from device to data coordinates
            xy = convert_coord(x, y, /DEVICE, /TO_DATA)
            xrange = reform(xy[0,*])
            yrange = reform(xy[1,*])
            
            ;Forward results to proper analysis method
            if self.amode[0] eq 2 then self -> Interval, xrange, yrange
            if ((self.amode[0] and  4) gt 0) then self -> Average, xrange
            if ((self.amode[0] and  8) gt 0) then self -> MVAB, xrange
            if ((self.amode[0] and 16) gt 0) then self -> vHT, xrange, yrange
            
            ;reset initial click
            self.x0 = -1
            self.y0 = -1
        endcase
    endcase
end


;+
;   Print the endpoints of interval within the data set.
;
; :Params:
;       XRANGE:             in, required, type=numeric
;                           A range of coordinate on the abscissa for which the data
;                               interval is to be printed.
;       YRANGE:             in, required, type=numeric
;                           A range of coordinate on the ordinate for which the data
;                               interval is to be printed.
;-
pro MrAbstractAnalysis::Interval, xrange, yrange
    compile_opt idl2
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        self -> Error_Handler
        void = error_message()
        return
    endif
    
    ;Get the data range.
    xy_data = self -> Data_Range(xrange, IRANGE=iRange)
    
    n = n_elements(xy_data[0,*])

    ;Make strings of the results
    x0 = string(xy_data[0,0], FORMAT='(f0.4)')
    x1 = string(xy_data[2,0], FORMAT='(f0.4)')
    
    ;Bracket data if there is more than one component
    if n eq 1 then begin
        y0 = string(xy_data[1,*], FORMAT='(f0.4)')
        y1 = string(xy_data[3,*], FORMAT='(f0.4)')
    endif else begin
        y0 = '[' + strjoin(string(xy_data[1,*], FORMAT='(f0.4)'), ', ') + ']'
        y1 = '[' + strjoin(string(xy_data[3,*], FORMAT='(f0.4)'), ', ') + ']'
    endelse

    ;Print the results
    print, FORMAT='(%"x0 = %s    y0 = %s")', x0, y0
    print, FORMAT='(%"x1 = %s    y1 = %s")', x1, y1
end


;+
;   Retrieve the coordinates of the mouse click and find the nearest data point.
;
; :Params:
;       EVENT:              in, required, type=structure
;                           An event structure returned by the windows manager.
;-
pro MrAbstractAnalysis::Get_Data_Point, event
    compile_opt idl2
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        self -> Error_Handler
        void = error_message()
        return
    endif
    
    ;Only care about button presses
    if event.type ne 0 then return

    ;Convert the clicked point to data coordinates and print the location
    coords = convert_coord(event.x, event.y, /DEVICE, /TO_DATA)
        
    ;Only care about button presses
    xy_data = self -> Data_Range([coords[0], coords[0]])
    
    n = n_elements(xy_data[0,*])

    ;Make strings of the results
    x_pt = string(xy_data[0,0], FORMAT='(f0.4)')
    
    ;Bracket data if there is more than one component
    if n eq 1 $
        then y_pt = string(xy_data[1,*], FORMAT='(f0.4)') $
        else y_pt = '[' + strjoin(string(xy_data[1,*], FORMAT='(f0.4)'), ', ') + ']'

    ;Print the results
    print, FORMAT='(%"x = %s   y = %s")', x_pt, y_pt
end


;+
;   The average value in a given interval.
;
; :Params:
;       XRANGE:             in, required, type=fltarr(3,3)
;                           The data range along the abscissa axis over which the average
;                               is to be taken.
;       LOCATION:           in, optional, type=intarr(2)
;                           The [col, row] location of the plot whose data is to be averaged.
;                               If not provided, the currently selected plot will be
;                               rotated (i.e. the one indexed by self.ifocus).
;
; :Keywords:
;       LIST_INDEX              in, optional, type=boolean, default=0
;                               If set, then `LOCATION` is actually the index within at
;                                   which the plot is stored.
;       PLOT_INDEX:             in, optional, type=int, default=0
;                               If set, then `LOCATION` is actually the 1D plot index of
;                                   the plot. The upper-left-most plot has a plot index of
;                                   1, and the plot index increases as you go down the
;                                   column, then across the row.
;-
pro MrAbstractAnalysis::MVAB, xrange, location
    compile_opt idl2
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        self -> Error_Handler
        void = error_message()
        return
    endif
    
;---------------------------------------------------------------------
;Check Inputs ////////////////////////////////////////////////////////
;---------------------------------------------------------------------

    ;Defaults
    list_index = keyword_set(list_index)
    plot_index = keyword_set(plot_index)

    ;Use the selected plot
    if n_elements(location) eq 0 then begin
        index = self.ifocus

    ;Check if the given location exists
    endif else begin
        exists = self -> plotExists(location, index, $
                                    PLOT_INDEX=plot_index, LIST_INDEX=list_index, $
                                    /TO_LIST_INDEX)
        if exists eq 0 then message, 'No plot exists at LOCATION. Returning.'
    endelse
    
;---------------------------------------------------------------------
;Get Data and Perform MVAB ///////////////////////////////////////////
;---------------------------------------------------------------------
    
    ;Get the data interval
    xy_data = self -> Data_Range(xrange, IRANGE=iRange)

    ;Retrieve the data and the dimension over which to take the mean
    (*self.allObjects)[index] -> GetProperty, INDEP=indep, DEP=dep, DIMENSION=dimension
    if n_elements(dimension) eq 0 then begin
        dims = size(dep, /DIMENSIONS)
        dimension = where(dims eq 3, count) + 1
        if count eq 0 then message, 'Data must be 3xN to perform MVAB.'
    endif

    ;perform MVA -- Transpose to ensure 3xN
    case dimension of
        1: eigvecs = mva(indep[iRange[0]:iRange[1]], transpose(dep[iRange[0]:iRange[1],*]), EIGVALS=eigvals)
        2: eigvecs = mva(indep[iRange[0]:iRange[1]], dep[*,iRange[0]:iRange[1]], EIGVALS=eigvals)
        else: message, 'Data must be a 3xN or Nx3 array.'
    endcase
    
;---------------------------------------------------------------------
;Print the Results ///////////////////////////////////////////////////
;---------------------------------------------------------------------
        
    ;print the results of MVAB to the command window
    nlm = ['N', 'M', 'L']
    print, '________________________________________________________________'
    print, 'MVAB eigenvalues and eigenvectors'

    print, 'Start time: ' + ssm_to_hms(xy_data[0])
    print, 'End time:   ' + ssm_to_hms(xy_data[2])
    print, 'l', 'x', 'y', 'z', format='(4(9x, a1))'
    for i=0, 2 do print, strtrim(string(nlm[i], eigvals[i], eigvecs[*,i], $
                                        format='(a1, 2x, f10.4, 3x, 3(f7.4, 3x))'), 1)
    
    ;print again in idl format easy copy and paste
    print, '________________________________________________________________'
    print, 'IDL Format for Copy + Paste'
    print, "tstart = '" + ssm_to_hms(xy_data[0]) + "'"
    print, "tend =   '" + ssm_to_hms(xy_data[2]) + "'"
    print, format='(a0, 3(f10.4, a0))', $
           'eigvals = [', eigvals[0], ', ', eigvals[1], ', ', eigvals[2], ']'
    print, format='(3(a0, f7.4), a0)', $
           'eigvecs = [[', eigvecs[0,0], ', ', eigvecs[1,0], ', ', eigvecs[2,0], '], $', $
           '           [', eigvecs[0,1], ', ', eigvecs[1,1], ', ', eigvecs[2,1], '], $', $
           '           [', eigvecs[0,2], ', ', eigvecs[1,2], ', ', eigvecs[2,2], ']]'
    
    ;reset the draw widget's user value
    if ptr_valid(self.tmatrix) $
        then *self.tmatrix = eigvecs $
        else self.tmatrix = ptr_new(eigvecs)
end



;+
;   Turn DRAW_BUTTON_EVENTS on or off.
;
; :Keywords:
;       ON:                     in, required, type=boolean, default=0
;                               Turn motion events on.
;       OFF:                    in, optional, type=boolean, default=0
;                               Turn motion events off.
;-
pro MrAbstractAnalysis::On_Off_Button_Events, $
ON = on, $
OFF = off
    compile_opt idl2
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        void = error_message()
        return
    endif
    
    ;Make sure ON or OFF is indicated
    on = keyword_set(on)
    off = keyword_set(off)
    if on + off ne 1 then message, 'Either ON or OFF must be set (but not both).'
    
    ;Check to see if motion events are on
    isOn = widget_info(self.drawID, /DRAW_BUTTON_EVENTS)
    
    ;Turn on?
    if keyword_set(on) then begin
        if isOn eq 0 then widget_control, self.drawID, DRAW_BUTTON_EVENTS=1
        
    ;Turn off?
    endif else if keyword_set(off) then begin
        if isOn eq 0 then return
        
        ;Turn motion events off only if nothing else needs them. All analysis modes
        ;(thus far) depend on Get_Interval, so just check for that.
        if (self.amode[1] eq 0) then $
            widget_control, self.drawID, DRAW_BUTTON_EVENTS=0
    endif
end



;+
;   Turn DRAW_MOTION_EVENTS on or off. When motion events are turned off, all events
;   are cleared.
;
; :Keywords:
;       ON:                     in, required, type=boolean, default=0
;                               Turn motion events on.
;       OFF:                    in, optional, type=boolean, default=0
;                               Turn motion events off.
;-
pro MrAbstractAnalysis::On_Off_Motion_Events, $
ON = on, $
OFF = off
    compile_opt idl2
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        void = error_message()
        return
    endif
    
    ;Make sure ON or OFF is indicated
    on = keyword_set(on)
    off = keyword_set(off)
    if on + off ne 1 then message, 'Either ON or OFF must be set (but not both).'
    
    ;Check to see if motion events are on
    isOn = widget_info(self.drawID, /DRAW_MOTION_EVENTS)
    
    ;Turn on?
    if keyword_set(on) then begin
        if isOn eq 0 then widget_control, self.drawID, DRAW_MOTION_EVENTS=1
    
    ;Turn off?
    endif else if keyword_set(off) then begin
        if isOn eq 0 then return
        
        ;Turn motion events off only if nothing else needs them. Check if the "active"
        ;flag is set.
        
        ;Cross Hairs, Show [X,Y]
        if self.amode[1] eq 0 then begin
            widget_control, self.drawID, DRAW_MOTION_EVENTS=0
            widget_control, self.drawID, /CLEAR_EVENTS
        endif
    endif
end


;+
;   Rotate 3-component time series data.
;
; :Params:
;       ROTMAT:             in, required, type=fltarr(3,3)
;                           A rotation matrix used in rotating the data found at `LOCATION`.
;       LOCATION:           in, optional, type=intarr(2)
;                           The [col, row] location of the plot whose data is to be rotated.
;                               If not provided, the currently selected plot will be
;                               rotated (i.e. the one indexed by self.ifocus).
;
; :Keywords:
;       LIST_INDEX              in, optional, type=boolean, default=0
;                               If set, then `LOCATION` is actually the index within at
;                                   which the plot is stored.
;       PLOT_INDEX:             in, optional, type=int, default=0
;                               If set, then `LOCATION` is actually the 1D plot index of
;                                   the plot. The upper-left-most plot has a plot index of
;                                   1, and the plot index increases as you go down the
;                                   column, then across the row.
;-
pro MrAbstractAnalysis::Rotate, rotmat, location, $
PLOT_INDEX = plot_index, $
LIST_INDEX = list_index
    compile_opt idl2
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        self -> Error_Handler
        void = error_message()
        return
    endif
    
;---------------------------------------------------------------------
;Check Inputs ////////////////////////////////////////////////////////
;---------------------------------------------------------------------
    
    setDefaultValue, plot_index, 0, /BOOLEAN
    setDefaultValue, list_index, 0, /BOOLEAN

    if n_params() eq 1 then $
        if n_elements(rotmat) eq 2 then location = rotmat

    ;Use the selected plot
    if n_elements(location) eq 0 then begin
        index = self.ifocus

    ;Check if the location exists
    endif else begin
        exists = self -> plotExists(location, index, $
                                    PLOT_INDEX=plot_index, LIST_INDEX=list_index, $
                                    /TO_LIST_INDEX)
        if exists eq 0 then message, 'No plot exists at LOCATION. Returning.'
    endelse
    
    ;Get the rotation matrix
    if n_elements(rotmat) ne 9 then begin
        if ptr_valid(self.tmatrix) $
            then rotmat = *self.tmatrix $
            else message, 'A rotation matrix must be provided.'
    endif
    
    
;---------------------------------------------------------------------
;Rotate the Data /////////////////////////////////////////////////////
;---------------------------------------------------------------------
    
    theObject = (*self.allObjects)[index]
    theObject -> GetProperty, DEP=dep
    
    dep = rotate_vector(rotmat, dep)
    dMin = min(dep, max=dMax)
    theObject -> SetProperty, DEP=dep, YRANGE=[dMin, dMax]
    
    self -> Draw
end


;+
;   Calculate the deHoffmann-Teller Velocity over a given interval.
;
;   Instructions::
;       1. Make sure "Focus" is selected from the "Cursor" menu.
;       2. Select "vHT" from the "Analysis" menu.
;       3. Select an interval of velocity data for which vHT is to be calculated.
;           a. Click + Hold/Drag + Release
;       4. Do the same with magnetic field data.
;           a. The intervals do not need to be the same. The first interval is the one
;               used. The second interval is merely to know in which plot the magnetic
;               field data is stored.
;
; :Params:
;       XRANGE:             in, required, type=numeric
;                           A range of coordinate on the abscissa for which the minimum
;                               variance coordinate system is to be found.
;       YRANGE:             in, required, type=numeric
;                           A range of coordinate on the ordinate for which the minimum
;                               variance coordinate system is to be found.
;-
pro MrAbstractAnalysis::vHT, xrange, yrange
    compile_opt idl2
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        self -> Error_Handler
        void = error_message()
        return
    endif
    
;---------------------------------------------------------------------
;Process the Interval ////////////////////////////////////////////////
;---------------------------------------------------------------------
    
    ;Store the first interval.
    if self.amode[2] lt 1 then begin
        xy_data = self -> Data_Range(xrange, iRange=vIndex)

        self.amode[2] += 1
        self.intervals = ptr_new([vIndex, self.ifocus])      ;[sInterval, eInterval, iRef]
        return
    endif
    
;---------------------------------------------------------------------
;Get the Data ////////////////////////////////////////////////////////
;---------------------------------------------------------------------

    ;Retrieve the data and the dimension over which to take the mean
    (*self.allObjects)[(*self.intervals)[2]] -> GetProperty, INDEP=t_v, DEP=v, DIMENSION=v_dim
    (*self.allObjects)[self.ifocus] -> GetProperty, INDEP=t_B, DEP=B, DIMENSION=B_dim
    
    ;Get the index range for magnetic field data.
    iRange = (*self.intervals)[0:1]
    xrange = t_v[iRange]
    xy_data = self -> Data_Range(xrange, IRANGE=bIndex)

;---------------------------------------------------------------------
;Check Dimensions ////////////////////////////////////////////////////
;---------------------------------------------------------------------
    
    ;Pick the dimension over which v_HT will be found
    if n_elements(v_dim) eq 0 then begin
        dims = size(v, /DIMENSIONS)
        v_dim = where(dims ne 3, count) + 1
        if count eq 1 then message, 'Velocity data must be 3xN to calculate $v_{HT}$.'
    endif
    
    ;Pick the dimension over which v_HT will be found
    if n_elements(B_dim) eq 0 then begin
        dims = size(B, /DIMENSIONS)
        B_dim = where(dims ne 3, count) + 1
        if count ne 1 then message, 'Magnetic field data must be 3xN to calculate $v_{HT}$.'
    endif
    
;---------------------------------------------------------------------
;Select Data Interval ////////////////////////////////////////////////
;---------------------------------------------------------------------
    t_B = t_B[bIndex[0]:bIndex[1]]
    t_v = t_v[iRange[0]:iRange[1]]

    ;Select the subarray of velocity data
    case v_dim of
        1: v = transpose(v[iRange[0]:iRange[1],*])
        2: v = v[*,iRange[0]:iRange[1]]
        else: message, 'Data must be a 3xN or Nx3 array.'
    endcase
    
    ;Select the subarray of magnetic field data
    case B_dim of
        1: B = transpose(B[bIndex[0]:bIndex[1],*])
        2: B = B[*,bIndex[0]:bIndex[1]]
        else: message, 'Data must be a 3xN or Nx3 array.'
    endcase
    
;---------------------------------------------------------------------
;Calculate deHoffmann-Teller Velocity ////////////////////////////////
;---------------------------------------------------------------------

    ;Interpolate the data.
    MrInterp_TS, B, v, t_B, t_v, B_interp, v_interp, /NO_COPY
    
    ;Calculate the deHoffmann-Teller velocity.
    v_ht = ht_velocity(v_interp, B_interp)
    
    ;print the results to the command window for easy Copy + Paste
    print, 'x', 'y', 'z', format='(13x, 2(a1, 11x), a1)'
    print, 'v_ht =', transpose(v_ht), format='(a6, 3(2x, f10.4))'
    print, format='(a0, 3(f10.4, a0))', $
           'v_ht = [', v_ht[0], ', ', v_ht[1], ', ', v_ht[2], ']'
    
    ;Reset
    self.amode[2] = 0
    ptr_free, self.intervals
end


;+
;   Clean up after the object is destroy
;-
pro MrAbstractAnalysis::cleanup
    ptr_free, self.intervals
    ptr_free, self.tmatrix
end


;+
;   The initialization method. Because MrAbstractAnalysis is an abstract class, it must
;   be inherited. Any attempts to instantiate a MrAbstractAnalysis object will result
;   in an error.
;-
function MrAbstractAnalysis::init
    compile_opt idl2
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        void = error_message()
        return, 0
    endif
    
    message, 'This is an abstract class and must be inherited.'
end


;+
;   The class definition statement.
;
; :Params:
;       CLASS:          out, optional, type=structure
;                       The class definition structure.
;-
pro MrAbstractAnalysis__define, class
    compile_opt idl2
    
    class = {MrAbstractAnalysis, $
             amode: intarr(3), $            ;[text mode, active, npts]
             intervals: ptr_new(), $        ;[sInterval, eInterval, iRef]
             tmatrix: ptr_new() $           ;Coordinate transformation matrix
            }
end
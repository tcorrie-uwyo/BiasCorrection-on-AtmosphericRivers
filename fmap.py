'''
fmap
Version: 3.1.0
Author: Tim Corrie III
Last updated: 04/11/2024

This module is a wrapper for cartopy to save space in the main code, using matplotlib as well.
It is necessary to run any notebooks where it's called without significant modification of code, specifically spatial plots.
It is a WIP and may be updated at any time.


Copyright: This module may be distributed and used freely, provided the following:
    - This module must not be modified except with written (in-person or electronically) permission.
    - The line below must be added exactly how it is presented (without quotes) with the import statement (convention is 'import fmap as fm'):
        "fmap is owned by Tim Corrie III, Copyright 2024."

'''

import matplotlib.pyplot as plt
import numpy as np
import cartopy.crs as ccrs
import cartopy.feature as cfeature
from matplotlib.ticker import FuncFormatter as FF
import matplotlib as mpl


def isiterable(obj):
    '''
    Determines if passed object can be iterated.

    Parameters:
    - obj (object): Any object/datatype.

    Returns:
        bool: True or False if the obj is iterable.

    '''
    try:
        iter(obj)
        return True
    except TypeError:
        return False


def axes_2d(axs, rows, cols):
    '''
    Takes an axes object and transforms it into a 2d array if necessary.

    Parameters:
    - axs (object or array_like): axs object created in make_plots function (see below)
    - rows (int): number of rows specified in the grid
    - cols (int): number of columns specified in the grid

    Returns:
        2d array of axes object (with both dimensions being one or more)
    '''
    if rows == 1 and cols == 1:
        return np.array([[axs]])
    elif rows > 1 and cols == 1:
        return np.array([axs]).transpose()
    elif rows == 1 and cols > 1:
        return np.array([axs])
    else:
        return axs


def make_plots(bounds, rows, cols, figtitle="", titlesize=18, adjusty=1.0, hpad=0, wpad=0):
    '''
    Creates a plot with the specified subplot configuration.

    Parameters:
    - bounds (array_like): The west, east, north, and south coordinates of the map boundaries, respectively. Required parameter. Careful that the data you're working with may have different reference coordinates.
    - rows (int): number of rows in the figure. Required parameter.
    - cols (int): number of columns in the figure. Required parameter.
    - figtitle (str): Give this plot a name. Default is blank but can be added later.
    - titlesize (int): Size of plot title. Default is 18.
    - adjusty (float): move the title up and down. Default is 1.0 (standard).
    - hpad (float): How much space to put between the rows (negative brings them closer together). Default is 0 (no change).
    - wpad (float): How much space to put between the columns (negative brings them closer together). Default is 0 (no change).

    Returns:
        fig, axes pair
    '''
    fig, axs = plt.subplots(rows, cols, subplot_kw=dict(projection=ccrs.PlateCarree()), figsize=(8*cols, 8*rows+2))
    axs = axes_2d(axs, rows, cols)
    for i in range(axs.size):
        ax = axs[i // cols, i % cols]
        ax.set_extent([bounds[0], bounds[1], bounds[3], bounds[2]])
        ax.add_feature(cfeature.STATES, edgecolor="black", zorder=100)
        ax.add_feature(cfeature.BORDERS, edgecolor="black", zorder=99)
    fig.suptitle(figtitle, fontsize=titlesize, y=adjusty)
    if rows >= 2:
        fig.subplots_adjust(hspace=hpad)
    if cols >= 2:
        fig.subplots_adjust(wspace=wpad)
    return fig, axs


def axes_labels(fig, axs, bounds, lonspacing, latspacing, label_size=10, style='all', rotation=None):
    '''
    Updates the axes x- and y- labels with coordinate information.

    Parameters:
    - fig (object): Overall figure object. Required parameter.
    - axs (object): 2d array of axs (see axes_2d and make_plots for the creation). Required parameter.
    - bounds (array_like): The west, east, north, and south coordinates of the map boundaries, respectively. Required parameter. Ideally this is the same as in the make_plots.
    - lonspacing (int): The spacing interval of longitude ticks labeled. Required parameter.
    - latspacing (int): The spacing interval of latitude ticks labeled. Required parameter.
    - label_size (int or float): Size of the labels. Default is 10.
    - style (str): Order in which labels are created. Default is 'all' (each subplot), but 'outer' is available (only left and bottom most subplots get lon and lat labels).
    - rotation (dict or None): How to rotate the labels. Default is None. If values are passed, the input must follow this format:
            rotation={'x': num_degx, 'y': num_degy}
            where num_deg{xy} is the number of degrees x or y to rotate. If only one of 'x' or 'y' are passed, the other is assumed to be 0.

    Returns:
        None
    '''

    def lon_formatter(x, pos):
        '''
        Formats the longitude to exclude negative signs and adds the appropriate letters.

        Parameters:
        - x: the longitude ticks
        - pos: position of each longitude tick.

        Notes:
        - No parameters are passed when this function is called.

        Returns:
            Formatted longitude ticks.
        '''
        if x % 180 == 0:
            return '{}°'.format(abs(x))
        elif x < 0:
            return '{}°W'.format(abs(x))
        elif x > 0:
            return '{}°E'.format(abs(x))

    def lat_formatter(y, pos):
        '''
        Formats the latitude to exclude negative signs and adds the appropriate letters.

        Parameters:
        - y: the latitude ticks
        - pos: position of each latitude tick.

        Notes:
        - No parameters are passed when this function is called.

        Returns:
            Formatted latitude ticks.
        '''
        if y < 0:
            return '{}°S'.format(abs(y))
        elif y > 0:
            return '{}°N'.format(abs(y))
        elif y == 0:
            return '{}°'.format(abs(y))

    # This block handles the subplots rotation based on the value passed.
    if rotation is None:
        rotx, roty = 0, 0
    elif isiterable(rotation):
        try:
            rotx = rotation['x']
        except KeyError:
            rotx = 0
        try:
            roty = rotation['y']
        except KeyError:
            roty = 0
    else:
        raise ValueError("'rotation' must be an x/y iterable, not {}".format(rotation))

    rows = axs.shape[0]
    cols = axs.shape[1]
    for i in range(axs.size):
        ax = axs[i // cols, i % cols]
        if style == 'all' or i // cols == rows-1:
            xticks = np.arange(bounds[0], bounds[1]+1, lonspacing)
            ax.set_xticks(xticks, crs=ccrs.PlateCarree())
            ax.set_xticklabels(xticks, fontsize=label_size, rotation=rotx)
            ax.xaxis.set_major_formatter(FF(lon_formatter))
        if style == 'all' or i % cols == 0:
            yticks = np.arange(bounds[3], bounds[2]+1, latspacing)
            ax.set_yticks(yticks, crs=ccrs.PlateCarree())
            ax.set_yticklabels(yticks, fontsize=label_size, rotation=roty)
            ax.yaxis.set_major_formatter(FF(lat_formatter))


def plot_var(fig, axis, varnames, style, cmap='rainbow', colors='black', normalization=False, prange=np.arange(0, 1.1, 0.1), alpha=0.8, crange=np.arange(0, 1.1, 0.1), extend='neither'):
    '''
    Plots a 3d-field on a subplot of a figure.

    Parameters:
    - fig (object): Figure to plot to. Required parameter.
    - axis (object): Axis to plot to. Required parameter.
    - varnames(list of array_likes): Variable names to plot. Requires x, y, and z variables as a 1-D list of 3 2-D variables (e.g. [longitude, latitude, field]). Required parameter.
    - style (str): Either 'contour' or 'contourf'. Required parameter.
    - cmap (Colormap Object or str): For contourf, sets the color scheme. Default is 'rainbow'.
    - colors (str): For contour, sets the contour colors. Default is 'black'.
    - normalization (bool): Determines if the colorbar should be normalized to better represent the data scale. Default is False.
    - prange (array_like): Range used for contourf. Default is 0 to 1 in 0.1 intervals.
    - alpha (float): Opacity of the contourf levels. Default is 0.8.
    - crange (array_like): Range used for contour. Default is 0 to 1 in 0.1 intervals.
    - cbar_include (bool): Include colorbar in the plot. Default is False.
    - extend (str): extend the range past the given bounds. Default is neither, can be set to 'min', 'max', or 'both'.

    Returns:
        Either the contourf object if plotted or None
    '''

    if isiterable(axis):
        raise TypeError('axis must be a single instance, not an iterable')
    else:
        if style == "contourf":
            varplot = axis.contourf(
                varnames[0], varnames[1], varnames[2], prange,
                norm=mpl.colors.LogNorm(vmin=prange[0], vmax=prange[-1]) if normalization else None,
                cmap=cmap, alpha=alpha, transform=ccrs.PlateCarree(), extend=extend)
        elif style == "contour":
            varplot = axis.contour(varnames[0], varnames[1], varnames[2], crange, colors=colors)
    return varplot


def make_colorbar(fig, axis, varplot, prec, cbar_orient, ticks, hide=1, cbar_axes=None, label='', shrink=1.0, pad=0.1, ticksize=10, ticklabelsize=14, labelsize=18):
    '''
    If contourf is plotted, make_colorbar will add a colorbar.

    Parameters:
    - fig (object): Figure to plot to. Required parameter.
    - axis (object): Axis to plot to. Required parameter.
    - varplot (object): The contourf map created with plot_var. Required parameter.
    - prec (dict_like str): How to format the tick labels in the colorbar or contour labels in contour. Required parameter. Options are:
    -         'precision, x' (uses np.round),
    -         'int' (uses .astype(int)),
    -         'strings' (use this if your tick labels are non-numerical.)
    -         (there may be more options in future versions.)
    - cbar_orient (str): Orientation of the colorbar. Options are 'horizontal' or 'vertical'. Required parameter.
    - ticks (array_like): Ticks to show. Required parameter.
    - hide (int): Hides all ticks except the first and every nth after. Default is 1, which shows all of them.
    - cbar_axes (object or array_like): Axis for which the colorbar applies to. Default is None, which defaults to the axis being plotted, but is recommended to be passed axis/axes.
    - label (str): label to give the colorbar. Default is blank, although it's generally a good idea to pass this.
    - shrink (float): Shrinks the colorbar by a given multiplication factor. Default is 1.0 (no shrink).
    - pad (float): Adjusts the position of the colorbar's y-position relative to the plot. Default is 0.1.
    - ticksize (int): Size of the actual ticks. Default is 10.
    - ticklabelsize (int): Size of the tick labels. Default is 14.
    - labelsize (int): Size of the colorbar label. Default is 18.

    Returns:
        None

    '''
    cbar = fig.colorbar(varplot, orientation=cbar_orient, ax=cbar_axes, shrink=shrink, pad=pad)
    cbar.set_label(label, fontsize=labelsize)
    cbar.set_ticks(ticks)
    if 'precision' in prec:
        int_round = int([p.lstrip().rstrip() for p in prec.split(',')][1])
        cbar.set_ticklabels(np.around(ticks, int_round))
    elif 'int' in prec:
        cbar.set_ticklabels(ticks.astype(int))
    else:
        cbar.set_ticklabels(ticks)
    cbar.ax.tick_params(labelsize=ticklabelsize, size=ticksize)
    for ct, tick in enumerate(cbar.ax.xaxis.get_ticklabels()):
        if ct % hide != 0:
            tick.set_visible(False)


def show_contour_labels(fig, axis, varplot, prec, labels, fontsize=10):
    '''
    Wrapper around ax.clabel to put labels on plots with line-contours.

    Parameters:
    - fig (object): Figure to plot to. Required parameter.
    - axis (object): Axis to plot to. Required parameter.
    - varplot (object): The contourf map created with plot_var. Required parameter.
    - labels (array_like): The labels to plot. Required parameter.
    - prec (dict_like str): How to format the tick labels in the colorbar or contour labels in contour. Required parameter. Options are:
    -         'precision, x' (uses np.round),
    -         'int' (uses .astype(int)),
    -         'strings' (use this if your tick labels are non-numerical.)
    -         (there may be more options in future versions.)
    - linewidths (float): Thickness of contour lines. Default is 1.0.
    - linestyles (str): How the lines are styles. Default is solid, options are None, 'solid', 'dashed', 'dashdot', 'dotted'
    - fontsize (int): Size of label font. Default is 10.

    Returns:
        None
    '''
    if 'precision' in prec:
        int_round = int([p.lstrip().rstrip() for p in prec.split(',')][1])
        axis.clabel(varplot, labels, inline=1, fontsize=fontsize, fmt='%.{}f'.format(int_round))
    elif 'int' in prec:
        axis.clabel(varplot, labels, inline=1, fontsize=fontsize, fmt='%.d')
    else:
        axis.clabel(varplot, labels, inline=1, fontsize=fontsize)


def plot_text(fig, axis, x, y, s, bgcolor='black', fontsize='small'):
    '''
    Plots text on the map. Relative to lat/lon coordinates for the map.

    Parameters:
    - fig (object): Figure to plot to. Required parameter.
    - axis (object): Axis to plot to. Required parameter.
    - x, y (float, float): longitude (latitude) of lower-left corner to plot text. Required parameters.
    - s (str): text of plot. Required parameter.
    - bgcolor (str or array_like): color of text to be plotted. Default is 'black'.
    - fontsize (str or int): size of text to be plotted. Default is 'small'. Can use relative size words or integers for absolute size.

    Returns:
        None
    '''
    axis.text(x, y, s, color=bgcolor, fontsize=fontsize, transform=ccrs.PlateCarree())


def plot_points(fig, axis, x, y, c, cmap, s=20):
    '''
    Plots multiple points at once as a scatter plot. Relative to lat/lon coordinates for the map.

    Parameters:
    - fig (object): Figure to plot to. Required parameter.
    - axis (object): Axis to plot to. Required parameter.
    - x, y (float, float): longitude (latitude) of lower-left corner to plot text. Required parameters.
    - c (str or array_like): color of markers to be plotted. Required parameter.
    - cmap (str or Colormap): colormap for marker values. Required parameter.
    - s (int): size of markers to be plotted. Default is 20.

    Returns:
        None
    '''
    axis.scatter(x, y, c=c, cmap=cmap, marker='o', s=s, edgecolors='black', transform=ccrs.PlateCarree())


def save(fig, path, tight_layout=True, dpi=300):
    '''
    Saves figure for later use or presentation

    Parameters:
    - fig (object): Figure object to save. Required parameter.
    - path (str): path (filename) of the saved image. Required parameter.
    - tight_layout (bool): Whether or not the figure's outer whitespace is removed. Default is True.
    - dpi (int): image quality, dots per inch. Default is 300.

    Returns:
        None
    '''
    if tight_layout:
        fig.savefig(path, dpi=dpi, bbox_inches='tight')
    else:
        fig.savefig(path, dpi=dpi)
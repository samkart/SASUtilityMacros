"""
PySpark equivalent of SAS `first.`
SAS ref -
https://blogs.sas.com/content/iml/2018/02/26/how-to-use-first-variable-and-last-variable-in-a-by-group-analysis-in-sas.html
"""


def frstDot(sdf, groupby=[], sortby=[], reversesort=False, complexsort=[], desc_str_datesort=False, customsort=None):
    """
    equivalent of SAS `first.` - by sm15491
    :param sdf: :class: `DataFrame`
    :param groupby: fields grouped on
    :param sortby: fields sorted on
    :param reversesort: sort order for sortby fields
    :param complexsort: list of bools; different sort order for sortby fields; True for ASC, False for DESC
    :param desc_str_datesort: boolean; dates and strings being sorted
    :param customsort: a custom sort function for the sort keys
    :return: :class: `DataFrame` with only single occurrences (row) of the group-sort key-value
    :usage:
        output_sdf = frstDot(
            spark_df,
            groupby=['col1', 'col2'],
            sortby=['dt_col', 'colb', 'colc'],
            customsort=lambda ok: (-int(ok.dt_col.strftime('%Y%m%d')), -ok.colb, ok.colc),
            reversesort=True
        )
    """

    assert (len(groupby) > 0) & (len(sortby) > 0), "groupby and sortby is required but one or both left blank"
    # check_complexsort = list(set([type(complexsort[i]) == bool for i in range(len(complexsort))]))
    # assert (len(check_complexsort) == 1) & (check_complexsort[0]), "boolean values required in complexsort"
    # del check_complexsort

    _dfschema = sdf.schema

    def _frstDotRule(groupedRows):
        """
        grouped and sorted on fields, retains the first logical occurrence
        :param groupedRows: collection of rows
        :return: list of lists with the calculated fields
        """

        _res = []
        _frstRec = True

        for row in groupedRows:
            if _frstRec:
                _frstRec = False
                _res.append([val for val in row])
            else:
                break

        return _res

    _groupKey = eval('lambda gk: ('+', '.join(['gk.' + k for k in groupby])+')')

    if customsort is not None:
        print('Sort function provided. Overriding all other complex sort criteria')
        complexsort = []
        desc_str_datesort = False
        _orderKey = customsort
    elif len(complexsort) > 0:
        if not desc_str_datesort:
            reversesort = False
            print("complexsort provided. reversesort criterion is being nullified.")
            _convert_sortkeys = ['-' if not k else '' for k in complexsort]
        elif desc_str_datesort:
            reversesort = True
            print("complexsort with desc_str_datesort provided. reversesort criterion is being forced.")
            _convert_sortkeys = ['-' if k else '' for k in complexsort]
        else:
            raise ValueError('Boolean value required denoting DESC sort order on str and date fields.')

        _complexsortkeytups = list(zip(sortby, _convert_sortkeys))
        _complexSortBy = [_complexsortkeytups[i][1]+'ok.'+_complexsortkeytups[i][0]
                          for i in range(len(_complexsortkeytups))]
        del _convert_sortkeys, _complexsortkeytups

        _orderKey = eval('lambda ok: ('+', '.join(_complexSortBy)+')')
    else:
        _orderKey = eval('lambda ok: ('+', '.join(['ok.' + k for k in sortby])+')')

    _res_rdd = sdf.rdd. \
        groupBy(_groupKey). \
        flatMapValues(lambda v: _frstDotRule(sorted(v, key=_orderKey, reverse=reversesort))). \
        values()

    _res_sdf = sdf.sql_ctx.createDataFrame(_res_rdd, _dfschema)

    print('**Dev Note**\nconsider creating a permanent table on Hive')

    return _res_sdf


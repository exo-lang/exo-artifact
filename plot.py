import json
import re
from collections import defaultdict

import click
import matplotlib.pyplot as plt


class Regex(click.ParamType):
    name = 'Regex'

    def convert(self, value, param, ctx):
        try:
            if isinstance(value, re.Pattern):
                return value
            return re.compile(value)
        except re.error:
            self.fail(f'invalid regular expression: {value}')


@click.command()
@click.option('-m', '--matcher',
              required=True,
              type=Regex(),
              help='Regex to extract "series" and "n" from the names of '
                   'benchmarks. Use Python\'s named capture syntax to define '
                   'matcher names, e.g. (?P<series>...)')
@click.option('-p', '--property', 'prop',
              default='real_time',
              show_default=True,
              help="Which property in the DATA files to plot")
@click.option('--title', default="", help="Title for the plot")
@click.option('-o', '--output', default=None, help="Output file")
@click.argument('datafiles', metavar='data', nargs=-1, required=True,
                type=click.File())
def main(matcher, prop, title, output, datafiles):
    """
    Plot JSON-formatted DATA files produced by Google Benchmark.
    """
    data = defaultdict(lambda: defaultdict(list))
    for f in datafiles:
        record = json.load(f)
        for point in record['benchmarks']:
            if m := matcher.match(point['name']):
                groups = m.groupdict()
                series = groups.get('series')
                data[series]['n'].append(float(groups['n']))
                data[series][prop].append(float(point[prop]))

    fig, ax = plt.subplots()

    for series, points in data.items():
        ax.plot(points['n'], points[prop], label=series)
    ax.set(xlabel='n', ylabel=prop, title=title)
    ax.set_ybound(lower=0, upper=None)
    ax.grid()
    ax.legend()

    if output:
        plt.savefig(output)
    else:
        plt.show()


if __name__ == '__main__':
    main()

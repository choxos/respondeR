# respondeR

This R package provides a Shiny application for performing responder analysis in clinical trials.

## Installation

You can install the development version of respondeR from GitHub with:

```r
# install.packages("devtools")
devtools::install_github("choxos/respondeR")
```

## Usage

To launch the Responder Analysis app, use the following command:

```r
respondeR::launch_responder_analysis()
```

## Features

- Upload your own data or use sample data
- Perform responder analysis using various methods:
  - Median
  - Unweighted Mean
  - Weighted Mean
  - Individual
- View and download results
- Interactive data tables for easy exploration

## Data Format

The app expects data in the following format:

| study   | change_e | sd_e | n_e | change_c | sd_c | n_c |
|---------|----------|------|-----|----------|------|-----|
| Study 1 | 0.958    | 1.26 | 43  | 0.218    | 1.20 | 45  |
| Study 2 | 0.792    | 1.28 | 139 | 0.003    | 1.32 | 145 |
| ...     | ...      | ...  | ... | ...      | ...  | ... |

Where:
- `study`: Study identifier
- `change_e`: Change in experimental group
- `sd_e`: Standard deviation in experimental group
- `n_e`: Sample size in experimental group
- `change_c`: Change in control group
- `sd_c`: Standard deviation in control group
- `n_c`: Sample size in control group

## Author

Ahmad Sofi-Mahmudi

## License

This project is licensed under the GNU GPL 3 License. See the [LICENSE](LICENSE) file for details.

## Contributing

Contributions to improve respondeR are welcome. Please feel free to submit a Pull Request.

## Support

If you encounter any problems or have any questions, please [open an issue](https://github.com/choxos/respondeR/issues) on GitHub.

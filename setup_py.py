from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="parquet-pipelines",
    version="1.0.0",
    author="4example",
    author_email="PP@4example.xyz",
    description="A minimal, SQL-first data transformation framework",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/yourorg/parquet-pipelines",
    packages=find_packages(),
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
    ],
    python_requires=">=3.8",
    install_requires=[
        "duckdb>=0.8.0",
        "pandas>=1.5.0",
        "pyarrow>=12.0.0",
        "sqlalchemy>=1.4.0",
        "pyodbc>=4.0.30",  # For SQL Server connectivity
        "pyyaml>=6.0",
        "click>=8.0.0",
    ],
    extras_require={
        "dev": [
            "pytest>=7.0.0",
            "pytest-cov>=4.0.0",
            "black>=22.0.0",
            "flake8>=5.0.0",
            "mypy>=1.0.0",
        ],
    },
    entry_points={
        "console_scripts": [
            "parquet-pipelines=parquet_pipelines.cli:main",
        ],
    },
    package_data={
        "parquet_pipelines": [
            "templates/*.yml",
            "templates/*.sql",
        ],
    },
    include_package_data=True,
)

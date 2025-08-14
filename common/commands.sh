generate_arxiv_latex() {
    local dir="$1"
    if [[ -z "$dir" ]]; then
        echo "Usage: generate_arxiv_latex <directory>"
        return 1
    fi

    arxiv_latex_cleaner "$dir" \
        --resize_images \
        --im_size 500 \
        --images_allowlist='{"images/im.png":2000}'
}

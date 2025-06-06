package ociutil

import (
	"context"

	"github.com/DataDog/rules_oci/go/internal/set"

	"github.com/containerd/containerd/content"
	"github.com/containerd/containerd/images"
	ocispec "github.com/opencontainers/image-spec/specs-go/v1"
)

// CopyContentHandler copies the parent descriptor from the provider to the
// ingestor
func CopyContentHandler(handler images.HandlerFunc, from content.Provider, to content.Ingester, mount bool) images.HandlerFunc {
	return func(ctx context.Context, desc ocispec.Descriptor) ([]ocispec.Descriptor, error) {
		err := CopyContent(ctx, from, to, desc, mount)
		if err != nil {
			return nil, err
		}

		return handler(ctx, desc)
	}
}

// CopyChildrenFromHandler performs a recursive depth-first copy of the parent descriptors children
// (as returned by calling handler on the parent) from the provider to the ingester
func CopyChildrenFromHandler(ctx context.Context, handler images.HandlerFunc, from content.Provider, to content.Ingester, parent ocispec.Descriptor, mount bool) error {
	children, err := handler.Handle(ctx, parent)
	if err != nil {
		return err
	}

	for _, child := range children {
		err = copyContentFromHandler(ctx, handler, from, to, child, mount)
		if err != nil {
			return err
		}
	}
	return nil
}

func copyContentFromHandler(ctx context.Context, handler images.HandlerFunc, from content.Provider, to content.Ingester, desc ocispec.Descriptor, mount bool) error {
	err := CopyChildrenFromHandler(ctx, handler, from, to, desc, mount)
	if err != nil {
		return err
	}

	err = CopyContent(ctx, from, to, desc, mount)
	if err != nil {
		return err
	}

	return nil
}

// ContentTypesFilterHandler filters the children of the handler to only include
// the listed content types
func ContentTypesFilterHandler(handler images.HandlerFunc, contentTypes ...string) images.HandlerFunc {
	set := make(set.String)
	set.Add(contentTypes...)
	return func(ctx context.Context, desc ocispec.Descriptor) ([]ocispec.Descriptor, error) {
		children, err := handler(ctx, desc)
		if err != nil {
			return nil, err
		}

		var rtChildren []ocispec.Descriptor
		for _, c := range children {
			if set.Contains(c.MediaType) {
				rtChildren = append(rtChildren, c)
			}
		}

		return rtChildren, nil
	}
}

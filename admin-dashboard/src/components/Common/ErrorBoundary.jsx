import React from 'react';

class ErrorBoundary extends React.Component {
    constructor(props) {
        super(props);

        this.state = {
            hasError: false,
            error: null,
        };
    }

    static getDerivedStateFromError(error) {
        return {
            hasError: true,
            error,
        };
    }

    componentDidCatch(error, errorInfo) {
        console.error('Dashboard Error:', error, errorInfo);
    }

    render() {
        if (this.state.hasError) {
            return (
                <div className="flex flex-col items-center justify-center min-h-screen bg-gray-100 p-6">
                    <h1 className="text-2xl font-bold text-red-600 mb-4">
                        Something went wrong
                    </h1>

                    <p className="text-gray-600 text-center max-w-md">
                        The dashboard encountered an unexpected error.
                        Please refresh the page or restart the application.
                    </p>

                    <button
                        onClick={() => window.location.reload()}
                        className="mt-6 px-5 py-2 bg-primary-600 text-white rounded-lg"
                    >
                        Reload Dashboard
                    </button>
                </div>
            );
        }

        return this.props.children;
    }
}

export default ErrorBoundary;